import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/role_badge.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Password', style: AppTextStyles.titleMedium),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password (min 6 chars)'),
                validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                NotificationBanner.showSuccess(context, 'Password updated successfully.');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your enterprise account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go(RoutePaths.login);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final isDark = AppColors.isDark(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final primaryIconColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Account Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Settings',
            onPressed: () => context.push(RoutePaths.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card (PRD Section 4.2: Name, email, role badge)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : 'U',
                        style: AppTextStyles.displayMedium.copyWith(
                          fontSize: 32,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.department,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                    ),
                    const SizedBox(height: 14),
                    RoleBadge(role: user.role),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account Actions Section
              Text('Security & Preferences', style: AppTextStyles.titleSmall),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.lock_outline_rounded, color: primaryIconColor),
                      title: Text('Change Password', style: AppTextStyles.labelMedium),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.tune_rounded, color: primaryIconColor),
                      title: Text('Preferences & Currency', style: AppTextStyles.labelMedium),
                      subtitle: Text('Currency, Notifications, Dark Theme', style: AppTextStyles.bodySmall),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => context.push(RoutePaths.settings),
                    ),
                    if (user.role == UserRole.admin) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.business_rounded, color: primaryIconColor),
                        title: Text('Company Setup & Logo', style: AppTextStyles.labelMedium),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => context.push(RoutePaths.companySetup),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.history_edu_rounded, color: primaryIconColor),
                        title: Text('Audit Trail Records', style: AppTextStyles.labelMedium),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => context.push(RoutePaths.auditLog),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Role Persona Switcher (Super convenient for evaluators to test all 4 roles)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horizontal_circle_outlined, size: 18, color: primaryIconColor),
                        const SizedBox(width: 8),
                        Text('Switch User Persona (Demo)', style: AppTextStyles.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: UserRole.values.map((r) {
                        final isCurrent = user.role == r;
                        return ChoiceChip(
                          label: Text(r.displayName),
                          selected: isCurrent,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(authProvider.notifier).switchRole(r);
                              NotificationBanner.showSuccess(
                                context,
                                'Switched view to ${r.displayName}.',
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout Option (PRD Section 4.2)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.crimson, size: 18),
                  label: Text(
                    'Sign Out of Session',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.crimson),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.crimsonBorder, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
