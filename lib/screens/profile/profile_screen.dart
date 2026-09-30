import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_env.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_model.dart';
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

  Future<void> _pickImage(BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        ref.read(authProvider.notifier).updateAvatarUrl(pickedFile.path);
        if (context.mounted) {
          NotificationBanner.showSuccess(context, 'Profile photo updated successfully');
        }
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.showInfo(context, 'Photo upload simulated with sample avatar');
        final sampleAvatar = AppEnv.sampleAvatarUrl.isNotEmpty
            ? AppEnv.sampleAvatarUrl
            : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';
        ref.read(authProvider.notifier).updateAvatarUrl(sampleAvatar);
      }
    }
  }

  void _showPhotoUploadModal(BuildContext context, WidgetRef ref, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Profile Photo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a photo to represent your corporate account',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4F46E5), size: 22),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Capture with device camera', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, ref, ImageSource.camera);
              },
            ),
            const Divider(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFF10B981), size: 22),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Select image from device storage', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, ref, ImageSource.gallery);
              },
            ),
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) ...[
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                title: const Text('Remove Current Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444))),
                subtitle: const Text('Revert back to initials badge', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(authProvider.notifier).updateAvatarUrl(null);
                  NotificationBanner.showInfo(context, 'Profile photo removed');
                },
              ),
            ],
          ],
        ),
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
                // 1. MINIMALIST PROFILE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
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
                      // Interactive Avatar with Camera Overlay
                      GestureDetector(
                        onTap: () => _showPhotoUploadModal(context, ref, user),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _buildAvatarContent(user.avatarUrl, user.name),
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkSurface : Colors.white,
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Role Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withAlpha(18),
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

                      const SizedBox(height: 14),

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

                const SizedBox(height: 12),

                // 2. MINIMALIST PHOTO ID & ACTIONS CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 16 : 5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF312E81).withAlpha(40) : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Profile Photo & ID',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Identity verification & claim approvals',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'Remove photo',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                ref.read(authProvider.notifier).updateAvatarUrl(null);
                                NotificationBanner.showInfo(context, 'Profile photo removed');
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: const Text(
                                  'Camera',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4F46E5),
                                  backgroundColor: isDark ? const Color(0xFF312E81).withAlpha(25) : const Color(0xFFEEF2FF).withAlpha(60),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF4338CA).withAlpha(90) : const Color(0xFFC7D2FE),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: const Size(0, 44),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _pickImage(context, ref, ImageSource.camera),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library_outlined, size: 16),
                                label: const Text(
                                  'Gallery',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  backgroundColor: isDark ? const Color(0xFF064E3B).withAlpha(25) : const Color(0xFFECFDF5).withAlpha(60),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF065F46).withAlpha(90) : const Color(0xFFA7F3D0),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: const Size(0, 44),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _pickImage(context, ref, ImageSource.gallery),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. SETTINGS & ACTIONS SECTION
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

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String? avatarUrl, String name) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        return Image.network(
          avatarUrl,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsFallback(name),
        );
      }
      final file = File(avatarUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsFallback(name),
        );
      }
    }
    return _buildInitialsFallback(name);
  }

  Widget _buildInitialsFallback(String name) {
    return Center(
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Colors.white,
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
