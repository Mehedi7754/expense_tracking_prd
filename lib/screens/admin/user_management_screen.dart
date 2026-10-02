import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/role_badge.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/user_management_provider.dart';

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

  void _showChangeRoleDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Role: ${user.name}', style: AppTextStyles.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.activeRoles.map((role) {
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final allUsers = ref.watch(userManagementProvider);

    final filtered = allUsers.where((u) {
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
              title: const Text('User Management'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: 'Invite / Add User',
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
        label: const Text('Add User'),
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
              hintText: 'Search user by name, email, or department...',
              initialValue: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final user = filtered[i];
                final isDark = Theme.of(ctx).brightness == Brightness.dark;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: user.isActive ? AppColors.getSurface(context) : AppColors.getSurfaceSubtle(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(context)),
                    boxShadow: isDark ? [] : AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.push('/profile/employee/${user.id}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: user.isActive ? AppColors.getSurfaceSubtle(context) : AppColors.getBorder(context),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0] : 'U',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: user.isActive ? AppColors.getTextPrimary(context) : AppColors.getTextMuted(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.name,
                                          style: AppTextStyles.titleSmall.copyWith(
                                            decoration: user.isActive ? null : TextDecoration.lineThrough,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      RoleBadge(role: user.role, compact: true),
                                      const SizedBox(width: 6),
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
                      if (!user.isApproved && (currentUser?.role.canApproveMembers ?? true)) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text(
                              'Approve Member',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              ref.read(userManagementProvider.notifier).approveUser(user.id);
                              NotificationBanner.showSuccess(
                                context,
                                '${user.name} has been approved as an active team member.',
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 6),
                      // Actions: Change Role, Activity & Activate/Deactivate Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                label: const Text('Role'),
                                onPressed: () => _showChangeRoleDialog(user),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.insights_rounded, size: 16),
                                label: const Text('Activity'),
                                onPressed: () => context.push('/profile/employee/${user.id}'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                user.isActive ? 'Active' : 'Deactivated',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: user.isActive ? AppColors.emeraldDark : AppColors.crimsonDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Switch(
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
        ],
      ),
    ),
  ),
);
  }
}
