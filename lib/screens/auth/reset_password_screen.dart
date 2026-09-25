import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() => _isLoading = false);
      NotificationBanner.showSuccess(
        context,
        'Password updated successfully. Please sign in with your new password.',
      );
      context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Set New Password'),
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
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.key_rounded, size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(height: 18),
                    Text('Create New Password', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Ensure your new password has at least 6 characters and includes letters and numbers.',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),
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
                            : const Text('Update Password'),
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
