import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  bool _isLoading = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
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

  Future<void> _handleSubmit() async {
    if (_cooldownSeconds > 0) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      _startCooldown();
      setState(() {
        _isLoading = false;
        _submitted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Account Recovery'),
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
            child: _submitted ? _buildConfirmationCard(context) : _buildFormCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
              child: Icon(Icons.lock_reset_rounded, size: 28, color: AppColors.getPrimary(context)),
            ),
            const SizedBox(height: 18),
            Text('Reset Your Password', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Enter the corporate email address linked to your account. We will dispatch a secure password reset link.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'alex.chen@enterprise.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter your email';
                if (!val.contains('@')) return 'Please enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Link'),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded, size: 36, color: AppColors.emerald),
          ),
          const SizedBox(height: 20),
          Text('Reset Link Dispatched', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'We have dispatched instructions and a single-use reset URL to ${_emailController.text}. Please check your inbox.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (_cooldownSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Rate limited: You can request another link in $_cooldownSeconds seconds.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            TextButton(
              onPressed: () {
                setState(() => _submitted = false);
              },
              child: const Text('Resend Reset Link'),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push(RoutePaths.resetPassword),
              child: const Text('Simulate Clicking Reset Link'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Return to Login'),
          ),
        ],
      ),
    );
  }
}
