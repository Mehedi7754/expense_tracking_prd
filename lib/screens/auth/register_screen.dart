import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _deptController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.projectMember;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _deptController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          department: _deptController.text.trim().isEmpty ? 'Operations' : _deptController.text.trim(),
        );

    if (success && mounted) {
      NotificationBanner.showSuccess(
        context,
        'Account created successfully as ${_selectedRole.displayName}!',
      );
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.primary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Header
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withAlpha(46),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'User Account Registration',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Register New User', style: AppTextStyles.displayMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Select your role to access role-specific financial dashboards, approvals, and metrics.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (authState.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withAlpha(60)),
                              ),
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Full Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
                          ),
                          const SizedBox(height: 14),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Corporate Email *',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter email';
                              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Role Selection Label
                          Text(
                            'Assign Role (determines dashboard & data permissions)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Role Selector Dropdown (Restricted: Exclude Main Admin & Finance from public registration)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<UserRole>(
                                value: _selectedRole,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                items: const [
                                  UserRole.projectMember,
                                  UserRole.projectManager,
                                  UserRole.viewer,
                                ].map((role) {
                                  return DropdownMenuItem<UserRole>(
                                    value: role,
                                    child: Row(
                                      children: [
                                        _buildRoleIndicatorDot(role),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            role.displayName,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedRole = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Role description pill & governance note
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getRoleDescription(_selectedRole),
                                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '🔒 Executive roles (Main Admin, Finance) require internal IT provisioning.',
                                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Department
                          TextFormField(
                            controller: _deptController,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              hintText: 'e.g. Field Survey, Finance, IT',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password *',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
                          ),
                          const SizedBox(height: 14),

                          // Confirm Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password *',
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withAlpha(50),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: authState.isLoading ? null : _handleRegister,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Create Account & Sign In',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Back to Login Link (responsive Wrap to prevent overflow)
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.pop(),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleIndicatorDot(UserRole role) {
    Color dotColor;
    switch (role) {
      case UserRole.mainAdmin:
        dotColor = AppColors.primary;
        break;
      case UserRole.projectManager:
        dotColor = AppColors.indigo;
        break;
      case UserRole.projectMember:
        dotColor = AppColors.textSecondary;
        break;
      case UserRole.finance:
        dotColor = AppColors.emerald;
        break;
      case UserRole.viewer:
        dotColor = Colors.blue;
        break;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.mainAdmin:
        return 'Full executive access: company financial position, all projects, revenue forecasting, user & category management.';
      case UserRole.projectManager:
        return 'Project-level access: manage assigned projects, cost cards, review & approve submitted expenses.';
      case UserRole.projectMember:
        return 'Field / staff access: submit project expenses, upload receipts, track receipt compliance (>50% warning).';
      case UserRole.finance:
        return 'Financial controller: approve expenses & justifications, company-wide audit, project budgets & margins.';
      case UserRole.viewer:
        return 'Read-only access: view permitted projects and audit reports without modification capabilities.';
    }
  }
}
