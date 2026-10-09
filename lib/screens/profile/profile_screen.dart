import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectProvider.notifier).fetchProjects(force: true);
    });
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditProfileDialog(user: user),
    );
  }

  void _handleLogout(BuildContext context) {
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

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
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

  void _showPhotoUploadModal(BuildContext context, UserModel user) {
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
                _pickImage(context, ImageSource.camera);
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
                _pickImage(context, ImageSource.gallery);
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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final allProjects = ref.watch(projectProvider);
    final assignedProjects = allProjects.where((p) {
      return p.hasMember(user.id) ||
          p.createdById == user.id ||
          user.assignedProjectIds.contains(p.id) ||
          user.assignedProjectIds.contains(p.projectId);
    }).toList();

    final int displayProjectCount = user.role == UserRole.mainAdmin
        ? (assignedProjects.isNotEmpty ? assignedProjects.length : allProjects.length)
        : assignedProjects.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(
          'Executive Profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh assignments',
            onPressed: () => ref.read(projectProvider.notifier).fetchProjects(force: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push(RoutePaths.settings),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(projectProvider.notifier).fetchProjects(force: true);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. EXECUTIVE IDENTITY HERO CARD
                  _buildHeroCard(context, user, isDark, displayProjectCount),

                  const SizedBox(height: 18),

                  // 2. ASSIGNED PROJECTS PORTFOLIO
                  _buildAssignedProjectsSection(context, user, assignedProjects, allProjects, isDark),

                  const SizedBox(height: 18),

                  // 3. OPERATIONS & GOVERNANCE
                  _buildSectionTitle('Operations & Governance', isDark),
                  const SizedBox(height: 8),
                  _buildOperationsCard(context, user, isDark),

                  const SizedBox(height: 18),

                  // 4. ACCOUNT & SECURITY
                  _buildSectionTitle('Account & Security', isDark),
                  const SizedBox(height: 8),
                  _buildAccountSecurityCard(context, user, isDark),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, UserModel user, bool isDark, int displayProjectCount) {
    final roleColor = user.role == UserRole.mainAdmin
        ? const Color(0xFF6366F1)
        : (user.role == UserRole.projectManager ? const Color(0xFF10B981) : const Color(0xFF0284C7));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 28 : 8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with edit camera button
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: roleColor.withAlpha(50),
                    width: 3,
                  ),
                ),
                child: AppAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.name,
                  size: 86,
                  textStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: roleColor,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showPhotoUploadModal(context, user),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Name & quick edit
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF4F46E5)),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showEditProfileDialog(context, user),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            user.email,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 8),

          // Role Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withAlpha(45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.role == UserRole.mainAdmin
                      ? Icons.shield_rounded
                      : (user.role == UserRole.projectManager ? Icons.verified_user_rounded : Icons.person_rounded),
                  size: 13,
                  color: roleColor,
                ),
                const SizedBox(width: 5),
                Text(
                  user.role.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: roleColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3 Executive Stat Cards
          Row(
            children: [
              _buildStatCard(
                value: '$displayProjectCount',
                label: user.role == UserRole.mainAdmin ? 'Portfolio' : 'Assigned',
                icon: Icons.folder_special_rounded,
                color: const Color(0xFF6366F1),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                value: user.department.isEmpty ? 'Corporate' : user.department,
                label: 'Department',
                icon: Icons.domain_rounded,
                color: const Color(0xFF0284C7),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                value: user.designation?.isNotEmpty == true ? user.designation! : 'Full-Time',
                label: 'Designation',
                icon: Icons.badge_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withAlpha(160) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155).withAlpha(140) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedProjectsSection(
    BuildContext context,
    UserModel user,
    List<ProjectModel> assignedProjects,
    List<ProjectModel> allProjects,
    bool isDark,
  ) {
    final isMainAdmin = user.role == UserRole.mainAdmin;
    final projectsToShow = isMainAdmin
        ? (assignedProjects.isNotEmpty ? assignedProjects : allProjects)
        : assignedProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildSectionTitle(
                  isMainAdmin ? 'Project Portfolio' : 'Assigned Projects',
                  isDark,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${projectsToShow.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
            if (isMainAdmin || allProjects.isNotEmpty)
              TextButton(
                onPressed: () => context.push(RoutePaths.projects),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF4F46E5),
                ),
                child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (projectsToShow.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 36,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No Assigned Projects',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  'Projects assigned to your account by a manager or admin will appear here.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 20 : 6),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: projectsToShow.take(4).length,
              separatorBuilder: (_, __) => _buildDivider(isDark),
              itemBuilder: (context, index) {
                final project = projectsToShow[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_rounded, color: Color(0xFF4F46E5), size: 19),
                  ),
                  title: Text(
                    project.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${project.projectId} • ${project.client}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project.status.displayName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  onTap: () => context.push(RoutePaths.projectDetail(project.id)),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOperationsCard(BuildContext context, UserModel user, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 6),
            blurRadius: 12,
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
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSecurityCard(BuildContext context, UserModel user, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Edit Profile & Details',
            subtitle: 'Update full name, email address & phone number',
            onTap: () => _showEditProfileDialog(context, user),
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
            icon: Icons.settings_outlined,
            iconColor: const Color(0xFF0284C7),
            title: 'App Settings',
            subtitle: 'Theme, currency, and notifications',
            onTap: () => context.push(RoutePaths.settings),
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildSettingsTile(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Sign Out',
            subtitle: 'Log out of this device',
            onTap: () => _handleLogout(context),
            isDark: isDark,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
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

