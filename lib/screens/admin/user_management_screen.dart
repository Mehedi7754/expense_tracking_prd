import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/role_badge.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/attendance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/salary_provider.dart';
import '../../state/user_management_provider.dart';

enum _UserFilter { all, pending, active, deactivated }

class UserManagementScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const UserManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  _UserFilter _selectedFilter = _UserFilter.all;

  void _showChangeRoleDialog(UserModel user) {
    final currentUser = ref.read(authProvider).currentUser;
    final isSuperAdmin = currentUser?.role == UserRole.mainAdmin;
    final allowedRoles = isSuperAdmin
        ? UserRole.activeRoles
        : [UserRole.projectManager, UserRole.projectMember];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Role: ${user.name}', style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: allowedRoles.map((role) {
            final isCurrent = user.role == role;
            return ListTile(
              title: Text(role.displayName, style: AppTextStyles.labelMedium),
              trailing: isCurrent ? const Icon(Icons.check_rounded, color: AppColors.emerald) : null,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(userManagementProvider.notifier).changeRole(user.id, role);
                NotificationBanner.showSuccess(
                  context,
                  'Role updated to ${role.displayName} for ${user.name}.',
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Employee: ${user.name}', style: AppTextStyles.titleMedium),
        content: Text(
          'Are you sure you want to permanently delete ${user.name} (${user.email})? This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(userManagementProvider.notifier)
                  .deleteUser(user.id, email: user.email);
              ref.read(attendanceProvider.notifier).invalidateCache();
              ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
              ref.read(salaryProvider.notifier).fetchOrgSalaryReport(force: true);
              if (mounted) {
                NotificationBanner.showWarning(
                  context,
                  'Employee ${user.name} permanently deleted.',
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isSelected
        ? AppColors.getPrimary(context)
        : (isHighlight && count > 0
            ? AppColors.amber.withValues(alpha: isDark ? 0.25 : 0.15)
            : AppColors.getSurface(context));
    final chipBorder = isSelected
        ? AppColors.getPrimary(context)
        : (isHighlight && count > 0
            ? AppColors.amber.withValues(alpha: 0.6)
            : AppColors.getBorder(context));
    final textColor = isSelected
        ? Colors.white
        : (isHighlight && count > 0 ? AppColors.amberDark : AppColors.getTextPrimary(context));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isHighlight && count > 0
                        ? AppColors.amber
                        : AppColors.getSurfaceSubtle(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isHighlight && count > 0 ? Colors.white : AppColors.getTextMuted(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final allUsers = ref.watch(userManagementProvider);

    final pendingUsers = allUsers.where((u) => !u.isApproved || !u.isActive).toList();
    final activeUsers = allUsers.where((u) => u.isApproved && u.isActive).toList();
    final deactivatedUsers = allUsers.where((u) => !u.isActive && u.isApproved).toList();

    List<UserModel> statusFiltered;
    switch (_selectedFilter) {
      case _UserFilter.pending:
        statusFiltered = pendingUsers;
        break;
      case _UserFilter.active:
        statusFiltered = activeUsers;
        break;
      case _UserFilter.deactivated:
        statusFiltered = deactivatedUsers;
        break;
      case _UserFilter.all:
        statusFiltered = allUsers;
        break;
    }

    final filtered = statusFiltered.where((u) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.department.toLowerCase().contains(q) ||
            u.role.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Employee Management'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: 'Add / Invite Employee',
                  onPressed: () => context.push(RoutePaths.addUser),
                ),
                const SizedBox(width: 8),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_add_user_fab',
        onPressed: () => context.push(RoutePaths.addUser),
        backgroundColor: AppColors.getPrimary(context),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Employee'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: CustomSearchBar(
                  hintText: 'Search employee by name, email, or department...',
                  initialValue: _searchQuery,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ),
              // Status Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        count: allUsers.length,
                        isSelected: _selectedFilter == _UserFilter.all,
                        onTap: () => setState(() => _selectedFilter = _UserFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Pending',
                        count: pendingUsers.length,
                        isHighlight: pendingUsers.isNotEmpty,
                        isSelected: _selectedFilter == _UserFilter.pending,
                        onTap: () => setState(() => _selectedFilter = _UserFilter.pending),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Active',
                        count: activeUsers.length,
                        isSelected: _selectedFilter == _UserFilter.active,
                        onTap: () => setState(() => _selectedFilter = _UserFilter.active),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Deactivated',
                        count: deactivatedUsers.length,
                        isSelected: _selectedFilter == _UserFilter.deactivated,
                        onTap: () => setState(() => _selectedFilter = _UserFilter.deactivated),
                      ),
                    ],
                  ),
                ),
              ),
              // Pending Notice Banner when on 'All' tab
              if (_selectedFilter == _UserFilter.all && pendingUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: AppColors.amberDark, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pendingUsers.length} employee${pendingUsers.length == 1 ? '' : 's'} awaiting approval',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.amberDark),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'New web registrations require administrator approval before mobile login.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setState(() => _selectedFilter = _UserFilter.pending),
                          child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(userManagementProvider.notifier).fetchUsers(force: true);
                  },
                  child: filtered.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _selectedFilter == _UserFilter.pending
                                            ? Icons.verified_user_outlined
                                            : Icons.people_outline_rounded,
                                        size: 48,
                                        color: AppColors.getTextMuted(context),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _selectedFilter == _UserFilter.pending
                                            ? 'No pending employee approvals'
                                            : 'No employees found matching filter',
                                        style: AppTextStyles.titleSmall.copyWith(
                                          color: AppColors.getTextMuted(context),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final user = filtered[i];
                            final isDark = Theme.of(ctx).brightness == Brightness.dark;
                            final isPending = !user.isApproved || !user.isActive;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? (isDark ? const Color(0xFF282114) : const Color(0xFFFFFBEB))
                                    : (user.isActive
                                        ? AppColors.getSurface(context)
                                        : AppColors.getSurfaceSubtle(context).withValues(alpha: 0.6)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPending
                                      ? AppColors.amber.withValues(alpha: 0.6)
                                      : AppColors.getBorder(context),
                                  width: isPending ? 1.4 : 1.0,
                                ),
                                boxShadow: isDark ? [] : AppColors.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => context.push(RoutePaths.employeeDetailPath(user.id)),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          imageUrl: user.avatarUrl,
                                          name: user.name,
                                          size: 40,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: AppTextStyles.titleSmall.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  decoration: user.isActive ? null : TextDecoration.lineThrough,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 5),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  RoleBadge(role: user.role, compact: true),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: user.isApproved
                                                          ? AppColors.emerald.withAlpha(20)
                                                          : AppColors.amber.withAlpha(25),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: user.isApproved
                                                            ? AppColors.emerald.withAlpha(70)
                                                            : AppColors.amber.withAlpha(90),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          user.isApproved
                                                              ? Icons.verified_user_rounded
                                                              : Icons.pending_actions_rounded,
                                                          size: 11,
                                                          color: user.isApproved ? AppColors.emeraldDark : AppColors.amberDark,
                                                        ),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          user.isApproved ? 'Approved' : 'Pending',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                            color: user.isApproved ? AppColors.emeraldDark : AppColors.amberDark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(user.email, style: AppTextStyles.bodySmall),
                                              Text(
                                                user.department,
                                                style: AppTextStyles.bodySmall.copyWith(
                                                  fontSize: 11,
                                                  color: AppColors.getTextMuted(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Edit icon button
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => context.push('/admin/users/${user.id}/edit'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if ((!user.isApproved || !user.isActive) && (currentUser?.role.canApproveMembers ?? true)) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.emerald,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                        label: const Text(
                                          'Approve & Activate Employee',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        onPressed: () async {
                                          await ref.read(userManagementProvider.notifier).approveUser(user.id);
                                          ref.read(attendanceProvider.notifier).invalidateCache();
                                          ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
                                          if (context.mounted) {
                                            NotificationBanner.showSuccess(
                                              context,
                                              '${user.name} approved and activated successfully.',
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 6),
                                  // Actions: Change Role, Activity & Activate/Deactivate Toggle
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          TextButton.icon(
                                            icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                                            label: const Text('Role', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () => _showChangeRoleDialog(user),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.insights_rounded, size: 15),
                                            label: const Text('Activity', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () => context.push(RoutePaths.employeeDetailPath(user.id)),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.crimson),
                                            label: const Text('Delete', style: TextStyle(color: AppColors.crimson, fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () => _showDeleteUserDialog(user),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            user.isActive ? 'Active' : 'Deactivated',
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: user.isActive ? AppColors.emeraldDark : AppColors.crimsonDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: user.isActive,
                                              activeTrackColor: AppColors.emerald,
                                              onChanged: (_) {
                                                ref.read(userManagementProvider.notifier).toggleActive(user.id);
                                                NotificationBanner.showWarning(
                                                  context,
                                                  user.isActive
                                                      ? '${user.name} account deactivated.'
                                                      : '${user.name} account activated.',
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
