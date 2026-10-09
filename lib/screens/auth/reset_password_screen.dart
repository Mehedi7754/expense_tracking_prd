import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';
import '../../repositories/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _passwordController.addListener(() => setState(() {}));
  }

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

  Future<void> _handleResendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      NotificationBanner.showError(context, 'Please enter a valid email address first.');
      return;
    }

    try {
      await ref.read(authRepositoryProvider).requestForgotPassword(email);
      _startCooldown();
      if (mounted) {
        NotificationBanner.showSuccess(
          context,
          'A new 6-digit verification code has been dispatched to $email.',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  int get _passwordStrength {
    final text = _passwordController.text;
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
    if (s == 3) return Colors.blue;
    return AppColors.emerald;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final otp = _otpController.text.trim();
      final newPass = _passwordController.text;

      await ref.read(authRepositoryProvider).resetPassword(
            email: email,
            otp: otp,
            newPassword: newPass,
          );

      if (mounted) {
        setState(() => _isLoading = false);
        NotificationBanner.showSuccess(
          context,
          'Password updated successfully! Please sign in with your new credentials.',
        );
        context.go(RoutePaths.login);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errMsg = e.toString().replaceAll('Exception: ', '');
        NotificationBanner.showError(
          context,
          errMsg.contains('400') || errMsg.toLowerCase().contains('invalid')
              ? 'Invalid or expired verification code. Please check or request a new code.'
              : errMsg,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getBorder(context)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.getPrimary(context).withValues(alpha: 0.16) : const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.key_rounded, size: 28, color: AppColors.getPrimary(context)),
                    ),
                    const SizedBox(height: 18),
                    Text('Set New Password', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 6-digit verification code sent to your email along with your new password.',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    Text('Corporate Email Address', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'alex.chen@enterprise.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your email';
                        if (!val.contains('@')) return 'Please enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // 6-Digit OTP Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('6-Digit Verification Code (OTP)', style: AppTextStyles.labelMedium),
                        if (_cooldownSeconds > 0)
                          Text(
                            'Resend in ${_cooldownSeconds}s',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          InkWell(
                            onTap: _handleResendOtp,
                            child: Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getPrimary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: '123456',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_rounded, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the 6-digit verification code';
                        }
                        if (val.trim().length != 6) {
                          return 'Verification code must be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // New Password Field
                    Text('New Password', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _passwordStrength / 4.0,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _strengthLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _strengthColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Confirm Password Field
                    Text('Confirm New Password', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 26),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleReset,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Reset & Update Password'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(RoutePaths.login),
                        child: const Text('Return to Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
