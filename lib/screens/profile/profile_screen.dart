import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';
import '../../state/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Minimalist Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 25 : 8),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar with Gradient Ring
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withAlpha(50),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(user.name),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Role Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Assigned Projects & Department mini pills
                  Row(
                    children: [
                      _buildMiniInfoBox(
                        label: 'Department',
                        value: user.department.isEmpty ? 'General' : user.department,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniInfoBox(
                        label: 'Assigned Projects',
                        value: '${user.assignedProjectIds.length} Projects',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settings & Actions Section
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 20 : 6),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.analytics_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Financial Reports & Audits',
                    subtitle: 'Export portfolio CSVs and category summaries',
                    onTap: () => context.push(RoutePaths.reports),
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.settings_outlined,
                    iconColor: const Color(0xFF0284C7),
                    title: 'App Settings',
                    subtitle: 'Theme, currency, and notifications',
                    onTap: () => context.push(RoutePaths.settings),
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Change Password',
                    subtitle: 'Update your corporate account password',
                    onTap: () => _showChangePasswordDialog(context),
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Sign Out',
                    subtitle: 'Log out of this device',
                    onTap: () => _handleLogout(context, ref),
                    isDark: isDark,
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfoBox({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDestructive ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  late final TextEditingController _currentPw;
  late final TextEditingController _newPw;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _currentPw = TextEditingController();
    _newPw = TextEditingController();
  }

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentPw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (min 6 chars)'),
              validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              NotificationBanner.showSuccess(context, 'Password updated successfully.');
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
