import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

class ProjectTeamScreen extends ConsumerWidget {
  final String projectId;

  const ProjectTeamScreen({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectProvider);
    final users = ref.watch(userManagementProvider);
    final expenses = ref.watch(expenseProvider);
    final currentUser = ref.watch(authProvider).currentUser;

    final match = projects.where((p) => p.id == projectId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Team')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final project = match.first;
    final teamMembers = users.where((u) => project.teamMemberIds.contains(u.id)).toList();
    final approvedExpenses = expenses
        .where((e) => e.projectId == projectId && e.status == ExpenseStatus.approved)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('${project.name} Team'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (currentUser?.role.canCreateProject == true)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Assign Members',
              onPressed: () => _showAssignMembersModal(context, ref, project),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: teamMembers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off_outlined, size: 54, color: AppColors.getTextMuted(context)),
                    const SizedBox(height: 12),
                    Text('No Team Members Assigned Yet', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Super Admin and Project Manager can assign members to work on ${project.name}.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextMuted(context)),
                      textAlign: TextAlign.center,
                    ),
                    if (currentUser?.role.canCreateProject == true) ...[
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getPrimary(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Assign Project Members', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => _showAssignMembersModal(context, ref, project),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: teamMembers.length,
              itemBuilder: (ctx, i) {
                final member = teamMembers[i];

                // Individual spend total for this project (PRD Section 4.4)
                double spend = 0.0;
                for (final exp in approvedExpenses.where((e) => e.employeeId == member.id)) {
                  spend += exp.amount;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getBorder(context)),
                    boxShadow: (Theme.of(context).brightness == Brightness.dark) ? [] : AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.getSurfaceSubtle(context),
                            child: Text(
                              member.name.isNotEmpty ? member.name[0] : 'U',
                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.getTextPrimary(context)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        member.name,
                                        style: AppTextStyles.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: member.isApproved
                                            ? AppColors.emerald.withAlpha(20)
                                            : AppColors.amber.withAlpha(25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            member.isApproved
                                                ? Icons.verified_user_rounded
                                                : Icons.pending_actions_rounded,
                                            size: 10,
                                            color: member.isApproved ? AppColors.emeraldDark : AppColors.amberDark,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            member.isApproved ? 'Approved' : 'Pending',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: member.isApproved ? AppColors.emeraldDark : AppColors.amberDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('${member.department} • ${member.role.displayName}', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  member.email,
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.getTextMuted(context)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(spend),
                                style: AppTextStyles.currencySmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Project Spend',
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.getTextMuted(context)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          if (currentUser?.role.canCreateProject == true)
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined, size: 19, color: Color(0xFFEF4444)),
                              tooltip: 'Remove from project',
                              onPressed: () async {
                                await ref.read(projectProvider.notifier).unassignMemberFromProject(project.id, member.id);
                                await ref.read(userManagementProvider.notifier).unassignUserFromProject(member.id, project.id);
                                if (context.mounted) {
                                  NotificationBanner.showInfo(context, '${member.name} unassigned from ${project.name}');
                                }
                              },
                            ),
                        ],
                      ),
                      if (!member.isApproved && (currentUser?.role.canApproveMembers ?? true)) ...[
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
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                            label: const Text(
                              'Approve Member',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () async {
                              await ref.read(userManagementProvider.notifier).approveUser(member.id);
                              if (context.mounted) {
                                NotificationBanner.showSuccess(
                                  context,
                                  '${member.name} has been approved for ${project.name}.',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAssignMembersModal(BuildContext context, WidgetRef ref, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, ref, _) {
            return StatefulBuilder(
              builder: (modalContext, setModalState) {
                final allUsers = ref.watch(userManagementProvider);
                final currentProjects = ref.watch(projectProvider);
                final liveProject = currentProjects.firstWhere(
                  (p) => p.id == project.id,
                  orElse: () => project,
                );
                final assignedIds = liveProject.teamMemberIds.toSet();

            final filteredUsers = allUsers.where((u) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return u.name.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  u.department.toLowerCase().contains(q) ||
                  (u.designation?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assign Project Members',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${assignedIds.length} members assigned to ${liveProject.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() => searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search members by name, email, department...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Member list
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No registered members found.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (itemCtx, i) {
                              final u = filteredUsers[i];
                              final isAssigned = assignedIds.contains(u.id);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isAssigned
                                      ? AppColors.getPrimary(context)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isAssigned ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        u.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: u.isApproved
                                            ? const Color(0xFF10B981).withAlpha(20)
                                            : const Color(0xFFF59E0B).withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        u.isApproved ? 'Approved' : 'Pending',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: u.isApproved ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${u.department} • ${u.role.displayName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      u.email,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!u.isApproved) ...[
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        onPressed: () async {
                                          await ref.read(userManagementProvider.notifier).approveUser(u.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showSuccess(context, '${u.name} approved');
                                          }
                                        },
                                        child: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Switch.adaptive(
                                      value: isAssigned,
                                      activeColor: AppColors.getPrimary(context),
                                      onChanged: (val) async {
                                        if (val) {
                                          await ref.read(projectProvider.notifier).assignMemberToProject(liveProject.id, u.id);
                                          await ref.read(userManagementProvider.notifier).assignUserToProject(u.id, liveProject.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showSuccess(
                                              context,
                                              '${u.name} assigned to ${liveProject.name}. They can now work on this project.',
                                            );
                                          }
                                        } else {
                                          await ref.read(projectProvider.notifier).unassignMemberFromProject(liveProject.id, u.id);
                                          await ref.read(userManagementProvider.notifier).unassignUserFromProject(u.id, liveProject.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showInfo(
                                              context,
                                              '${u.name} unassigned from ${liveProject.name}',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  },
);
}
}
