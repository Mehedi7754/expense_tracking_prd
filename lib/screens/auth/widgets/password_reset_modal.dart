import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../../repositories/auth_repository.dart';

enum PasswordResetStep {
  email,
  otp,
  newPassword,
  success,
}

class PasswordResetModal extends ConsumerStatefulWidget {
  final String? initialEmail;
  final VoidCallback? onComplete;
  final bool isBottomSheet;

  const PasswordResetModal({
    super.key,
    this.initialEmail,
    this.onComplete,
    this.isBottomSheet = true,
  });

  static Future<void> show(BuildContext context, {String? initialEmail, VoidCallback? onComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PasswordResetModal(
        initialEmail: initialEmail,
        onComplete: onComplete,
        isBottomSheet: true,
      ),
    );
  }

  @override
  ConsumerState<PasswordResetModal> createState() => _PasswordResetModalState();
}

class _PasswordResetModalState extends ConsumerState<PasswordResetModal> {
  PasswordResetStep _currentStep = PasswordResetStep.email;

  final _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String _otpError = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _startCooldown() {
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  int get _passwordStrength {
    final text = _newPasswordController.text;
    if (text.isEmpty) return 0;
    int score = 0;
    if (text.length >= 6) score++;
    if (text.length >= 8) score++;
    if (RegExp(r'[0-9]').hasMatch(text)) score++;
    if (RegExp(r'[!@#\$&*~%_\-]').hasMatch(text)) score++;
    return score;
  }

  String get _strengthLabel {
    final s = _passwordStrength;
    if (s <= 1) return 'Weak';
    if (s <= 2) return 'Fair';
    if (s == 3) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    final s = _passwordStrength;
    if (s <= 1) return AppColors.crimson;
    if (s <= 2) return AppColors.amber;
    if (s == 3) return const Color(0xFF3B82F6);
    return AppColors.emerald;
  }

  // --- Step 1: Request OTP ---
  Future<void> _handleSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      await ref.read(authRepositoryProvider).requestForgotPassword(email);
      _startCooldown();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = PasswordResetStep.otp;
          _otpError = '';
        });
        // Auto focus first OTP box
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _otpFocusNodes[0].canRequestFocus) {
            _otpFocusNodes[0].requestFocus();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errMsg = e.toString().replaceAll('Exception: ', '');
        NotificationBanner.showError(context, errMsg);
      }
    }
  }

  // --- Step 2: Resend OTP ---
  Future<void> _handleResendOtp() async {
    if (_cooldownSeconds > 0) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await ref.read(authRepositoryProvider).requestForgotPassword(email);
      _startCooldown();
      if (mounted) {
        NotificationBanner.showSuccess(
          context,
          'A new verification code has been dispatched to $email.',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // --- Step 2: Verify OTP ---
  Future<void> _handleVerifyOtp() async {
    final otp = _otpCode;
    if (otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = '';
    });

    final email = _emailController.text.trim();

    try {
      final isValid = await ref.read(authRepositoryProvider).verifyOtp(email, otp);
      if (isValid) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = PasswordResetStep.newPassword;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _otpError = 'Invalid or expired code. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // --- Step 3: Reset Password ---
  Future<void> _handleResetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      NotificationBanner.showError(context, 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final otp = _otpCode;

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: email,
            otp: otp,
            newPassword: newPass,
          );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = PasswordResetStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errMsg = e.toString().replaceAll('Exception: ', '');
        NotificationBanner.showError(
          context,
          errMsg.contains('400') || errMsg.toLowerCase().contains('invalid')
              ? 'Verification code expired. Please request a new one.'
              : errMsg,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.border;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_currentStep),
        child: _buildCurrentStepContent(context),
      ),
    );

    if (widget.isBottomSheet) {
      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 12,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              _buildStepIndicator(context),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepIndicator(context),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  // --- Step Indicator (1. Email -> 2. OTP -> 3. Password) ---
  Widget _buildStepIndicator(BuildContext context) {
    if (_currentStep == PasswordResetStep.success) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);

    int activeIndex = 0;
    if (_currentStep == PasswordResetStep.otp) activeIndex = 1;
    if (_currentStep == PasswordResetStep.newPassword) activeIndex = 2;

    Widget buildDot(int index, String label, IconData icon) {
      final isDone = activeIndex > index;
      final isCurrent = activeIndex == index;

      Color circleBg;
      Color iconColor;
      if (isDone) {
        circleBg = AppColors.emerald;
        iconColor = Colors.white;
      } else if (isCurrent) {
        circleBg = primary;
        iconColor = Colors.white;
      } else {
        circleBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        iconColor = isDark ? Colors.white38 : Colors.black38;
      }

      return Expanded(
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : Icon(icon, size: 16, color: iconColor),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? (isDark ? Colors.white : AppColors.textPrimary)
                    : (isDark ? Colors.white38 : AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildDivider(int index) {
      final isPassed = activeIndex > index;
      return Container(
        width: 36,
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: isPassed ? AppColors.emerald : (isDark ? Colors.white12 : Colors.black12),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildDot(0, 'Email', Icons.mail_outline_rounded),
          buildDivider(0),
          buildDot(1, 'Verify OTP', Icons.pin_outlined),
          buildDivider(1),
          buildDot(2, 'New Pass', Icons.lock_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context) {
    switch (_currentStep) {
      case PasswordResetStep.email:
        return _buildEmailStep(context);
      case PasswordResetStep.otp:
        return _buildOtpStep(context);
      case PasswordResetStep.newPassword:
        return _buildNewPasswordStep(context);
      case PasswordResetStep.success:
        return _buildSuccessStep(context);
    }
  }

  // ==================== STEP 1: EMAIL ====================
  Widget _buildEmailStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mail_lock_rounded, size: 22, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter your email to receive a 6-digit OTP',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Corporate Email Address',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'alex.chen@enterprise.com',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
              suffixIcon: _emailController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _emailController.clear()),
                    )
                  : null,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your corporate email';
              if (!val.contains('@') || !val.contains('.')) return 'Please enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleSendOtp,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Send Verification Code', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                if (widget.isBottomSheet) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              child: Text(
                'Cancel & Return',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 2: OTP VERIFICATION ====================
  Widget _buildOtpStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 22, color: AppColors.emerald),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter 6-Digit Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Sent to ${_emailController.text}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() => _currentStep = PasswordResetStep.email),
                        child: Text(
                          'Edit',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 6-box PIN input
        _buildOtpBoxes(context),

        if (_otpError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.crimson),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _otpError,
                  style: const TextStyle(fontSize: 12, color: AppColors.crimson, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Didn't receive code?",
              style: TextStyle(fontSize: 12.5, color: textSecondary),
            ),
            if (_cooldownSeconds > 0)
              Text(
                'Resend in ${_cooldownSeconds}s',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
              )
            else
              InkWell(
                onTap: _handleResendOtp,
                child: Text(
                  'Resend OTP Code',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleVerifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Verify Code', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back to Email'),
            onPressed: () => setState(() => _currentStep = PasswordResetStep.email),
          ),
        ),
      ],
    );
  }

  // 6 Segmented PIN boxes
  Widget _buildOtpBoxes(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final boxBg = isDark ? AppColors.darkSurfaceSubtle : const Color(0xFFF8F9FD);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6), // Supports pasting full 6 digits
            ],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: boxBg,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cardBorder, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
            onChanged: (value) {
              // If user pastes multi-digit OTP code
              if (value.length > 1) {
                final digits = value.split('').take(6).toList();
                for (int i = 0; i < digits.length; i++) {
                  _otpControllers[i].text = digits[i];
                }
                if (digits.length == 6) {
                  _otpFocusNodes[5].unfocus();
                  _handleVerifyOtp();
                } else {
                  _otpFocusNodes[digits.length].requestFocus();
                }
                return;
              }

              if (value.isNotEmpty) {
                if (index < 5) {
                  _otpFocusNodes[index + 1].requestFocus();
                } else {
                  _otpFocusNodes[index].unfocus();
                  _handleVerifyOtp();
                }
              } else if (value.isEmpty && index > 0) {
                _otpFocusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  // ==================== STEP 3: NEW PASSWORD ====================
  Widget _buildNewPasswordStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lock_reset_rounded, size: 22, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set New Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create a secure password for your account',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // New Password Field
          Text(
            'New Password',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) return 'Password must be at least 6 characters long';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Password Strength Bar
          if (_newPasswordController.text.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrength / 4,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _strengthLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _strengthColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            const SizedBox(height: 10),
          ],

          // Confirm Password Field
          Text(
            'Confirm New Password',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.shield_outlined, size: 19),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (val) {
              if (val != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleResetPassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update & Save Password', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to OTP'),
              onPressed: () => setState(() => _currentStep = PasswordResetStep.otp),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 4: SUCCESS ====================
  Widget _buildSuccessStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF4F46E5);
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.emerald),
          ),
          const SizedBox(height: 16),
          Text(
            'Password Reset Complete!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your password has been successfully updated. You can now log into your account using your new credentials.',
            style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (widget.onComplete != null) {
                  widget.onComplete!();
                } else {
                  if (widget.isBottomSheet) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                }
              },
              child: const Text('Sign In Now', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
