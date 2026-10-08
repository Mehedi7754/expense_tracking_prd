import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditProfileDialog(user: user),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(RoutePaths.login);
              }
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
        final bytes = await pickedFile.readAsBytes();
        final ext = pickedFile.name.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final base64Uri = AppImageHelper.bytesToBase64DataUri(bytes, mime: mime);
        await ref.read(authProvider.notifier).updateAvatarUrl(base64Uri);
        if (context.mounted) {
          NotificationBanner.showSuccess(context, 'Profile photo updated and saved to server');
        }
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.showError(context, 'Could not access photo: $e');
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
      return const Scaffold(body: SizedBox.shrink());
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(isDark ? 20 : 6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _buildAvatarContent(user.avatarUrl, user.name, isDark),
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showEditProfileDialog(context, ref, user),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
                            ),
                          ),
                        ],
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
                      if (user.role == UserRole.mainAdmin || user.role == UserRole.projectManager) ...[
                        _buildSettingsTile(
                          icon: Icons.person_add_alt_1_rounded,
                          iconColor: const Color(0xFF0D9488),
                          title: 'Add Employee',
                          subtitle: user.role == UserRole.mainAdmin
                              ? 'Provision Admin, Manager, or Employee accounts'
                              : 'Provision Manager or Employee accounts',
                          onTap: () => context.push(RoutePaths.addUser),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        _buildSettingsTile(
                          icon: Icons.people_alt_outlined,
                          iconColor: const Color(0xFF6366F1),
                          title: 'Employee Management & Governance',
                          subtitle: 'View employees, assign roles, company setup & audit logs',
                          onTap: () => context.push(RoutePaths.userManagement),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                      ],
                      if (user.role.canManageAttendanceAndSalary) ...[
                        _buildSettingsTile(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFF4F46E5),
                          title: 'Attendance & Geo-Tracking',
                          subtitle: 'Live staff pins, morning/afternoon records & office timing settings',
                          onTap: () => context.push(RoutePaths.attendanceDashboard),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        _buildSettingsTile(
                          icon: Icons.payments_outlined,
                          iconColor: const Color(0xFF10B981),
                          title: 'Salary & Attendance Deductions',
                          subtitle: 'Monthly payroll calculations, daily rates & absence deductions',
                          onTap: () => context.push(RoutePaths.salaryDashboard),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                      ] else ...[
                        _buildSettingsTile(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFF4F46E5),
                          title: 'My Attendance & Location',
                          subtitle: 'Morning/Afternoon check-in and GPS history',
                          onTap: () => context.push(RoutePaths.myAttendance),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        _buildSettingsTile(
                          icon: Icons.payments_outlined,
                          iconColor: const Color(0xFF10B981),
                          title: 'My Salary Statement',
                          subtitle: 'Monthly salary, working days and attendance deductions',
                          onTap: () => context.push(RoutePaths.mySalary),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                      ],
                      if (user.role != UserRole.projectMember) ...[
                        _buildSettingsTile(
                          icon: Icons.analytics_outlined,
                          iconColor: const Color(0xFF4F46E5),
                          title: 'Financial Reports & Audits',
                          subtitle: 'Export portfolio CSVs and category summaries',
                          onTap: () => context.push(RoutePaths.reports),
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                      ],
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
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Edit Profile & Details',
                        subtitle: 'Update full name, email address & phone number',
                        onTap: () => _showEditProfileDialog(context, ref, user),
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

  Widget _buildAvatarContent(String? avatarUrl, String name, bool isDark) {
    return AppAvatar(
      imageUrl: avatarUrl,
      name: name,
      size: 84,
      textStyle: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Colors.white,
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
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  late final TextEditingController _currentPw;
  late final TextEditingController _newPw;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).changePassword(
        currentPassword: _currentPw.text.trim(),
        newPassword: _newPw.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        NotificationBanner.showSuccess(context, 'Password updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().contains('400') || e.toString().contains('incorrect')
            ? 'Current password is incorrect'
            : 'Failed to update password: $e';
        NotificationBanner.showError(context, msg);
      }
    }
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
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'Current Password'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPw,
              obscureText: true,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'New Password (min 6 chars)'),
              validator: (v) => v == null || v.length < 6 ? 'At least 6 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileDialog({required this.user});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).updateAccountDetails(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        NotificationBanner.showSuccess(context, 'Profile details updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationBanner.showError(context, 'Failed to update profile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Account Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

