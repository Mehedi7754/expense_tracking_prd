import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
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
    final canManageTeam = currentUser?.role.canCreateProject == true ||
        (currentUser != null && project.canMemberManageTeam(currentUser.id));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('${project.name} Team'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManageTeam)
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
                      'Super Admin and Project Managers can assign members to work on ${project.name}.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextMuted(context)),
                      textAlign: TextAlign.center,
                    ),
                    if (canManageTeam) ...[
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
                final projMember = project.getMember(member.id);
                final roleInProject = projMember?.roleInProject.isNotEmpty == true
                    ? projMember!.roleInProject
                    : 'Member';
                final perms = projMember?.permissions ?? const ProjectPermissions();

                // Individual spend total for this project
                double spend = 0.0;
                for (final exp in approvedExpenses.where((e) => e.employeeId == member.id)) {
                  spend += exp.amount;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            imageUrl: member.avatarUrl,
                            name: member.name,
                            size: 44,
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
                                        member.name,
                                        style: AppTextStyles.titleSmall,
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
                                Text(
                                  '${member.department} • System: ${member.role.displayName}',
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                // Custom Project Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.getPrimary(context).withAlpha(16),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.getPrimary(context).withAlpha(50),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.badge_outlined,
                                        size: 12,
                                        color: AppColors.getPrimary(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        roleInProject,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.getPrimary(context),
                                        ),
                                      ),
                                    ],
                                  ),
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Granular Permission Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (perms.canApproveExpenses)
                            _permBadge(context, 'Claims Approver', const Color(0xFF10B981), Icons.verified_user_rounded),
                          if (perms.canViewBudget)
                            _permBadge(context, 'Budget', const Color(0xFF3B82F6), Icons.account_balance_wallet_outlined),
                          if (perms.canRecordRevenue)
                            _permBadge(context, 'Revenue', const Color(0xFF8B5CF6), Icons.payments_outlined),
                          if (perms.canCreateExpenses)
                            _permBadge(context, 'Submit Expenses', const Color(0xFF0284C7), Icons.receipt_long_outlined),
                          if (perms.canManageTasks)
                            _permBadge(context, 'Tasks', const Color(0xFFF59E0B), Icons.assignment_outlined),
                          if (perms.canUpdateProgress)
                            _permBadge(context, 'Progress', const Color(0xFF06B6D4), Icons.trending_up_rounded),
                          if (perms.canManageTeam)
                            _permBadge(context, 'Manage Team', const Color(0xFFEC4899), Icons.groups_outlined),
                          if (perms.canEditProject)
                            _permBadge(context, 'Edit Project', const Color(0xFF6366F1), Icons.edit_note_rounded),
                          if (perms.canViewAttendance)
                            _permBadge(context, 'Attendance', const Color(0xFF64748B), Icons.location_on_outlined),
                        ],
                      ),
                      if (canManageTeam) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: const Text('Role & Permissions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              onPressed: () => _showMemberPermissionsModal(context, ref, project, member),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'Remove from project',
                              visualDensity: VisualDensity.compact,
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
                      ],
                      if (!member.isApproved && (currentUser?.role.canApproveMembers ?? true)) ...[
                        const SizedBox(height: 8),
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

  Widget _permBadge(BuildContext context, String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: color),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberPermissionsModal(
    BuildContext context,
    WidgetRef ref,
    ProjectModel project,
    UserModel member,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projMember = project.getMember(member.id);
    final initialRole = projMember?.roleInProject.isNotEmpty == true
        ? projMember!.roleInProject
        : 'Member';
    final currentPerms = projMember?.permissions ?? const ProjectPermissions();

    final roleController = TextEditingController(text: initialRole);
    bool canViewBudget = currentPerms.canViewBudget;
    bool canRecordRevenue = currentPerms.canRecordRevenue;
    bool canViewExpenses = currentPerms.canViewExpenses;
    bool canCreateExpenses = currentPerms.canCreateExpenses;
    bool canApproveExpenses = currentPerms.canApproveExpenses;
    bool canManageTasks = currentPerms.canManageTasks;
    bool canUpdateProgress = currentPerms.canUpdateProgress;
    bool canManageTeam = currentPerms.canManageTeam;
    bool canEditProject = currentPerms.canEditProject;
    bool canViewAttendance = currentPerms.canViewAttendance;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void applyPreset(String roleName, ProjectPermissions p) {
              setSheetState(() {
                roleController.text = roleName;
                canViewBudget = p.canViewBudget;
                canRecordRevenue = p.canRecordRevenue;
                canViewExpenses = p.canViewExpenses;
                canCreateExpenses = p.canCreateExpenses;
                canApproveExpenses = p.canApproveExpenses;
                canManageTasks = p.canManageTasks;
                canUpdateProgress = p.canUpdateProgress;
                canManageTeam = p.canManageTeam;
                canEditProject = p.canEditProject;
                canViewAttendance = p.canViewAttendance;
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project Access: ${member.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Role & granular permissions for ${project.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      children: [
                        // Custom Role Field
                        const Text(
                          'Project Role Title',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: roleController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Site Lead, Field Auditor, Site Engineer',
                            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.getBorder(context)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Presets
                        const Text(
                          'Quick Role Presets',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              label: const Text('Site Lead (All)'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => applyPreset(
                                'Site Lead',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: true,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: true,
                                  canManageTasks: true,
                                  canUpdateProgress: true,
                                  canManageTeam: true,
                                  canEditProject: true,
                                  canViewAttendance: true,
                                ),
                              ),
                            ),
                            ActionChip(
                              label: const Text('Field Auditor (Approver)'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => applyPreset(
                                'Field Auditor',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: false,
                                  canApproveExpenses: true,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                            ),
                            ActionChip(
                              label: const Text('Site Engineer'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => applyPreset(
                                'Site Engineer',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: false,
                                  canManageTasks: true,
                                  canUpdateProgress: true,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                            ),
                            ActionChip(
                              label: const Text('Field Crew'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => applyPreset(
                                'Field Crew',
                                const ProjectPermissions(
                                  canViewBudget: false,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: false,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                            ),
                            ActionChip(
                              label: const Text('Observer'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => applyPreset(
                                'Observer',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: false,
                                  canApproveExpenses: false,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Highlighted Expense Approver Permission Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: canApproveExpenses
                                ? const Color(0xFF10B981).withAlpha(18)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: canApproveExpenses ? const Color(0xFF10B981) : AppColors.getBorder(context),
                              width: canApproveExpenses ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: canApproveExpenses,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setSheetState(() => canApproveExpenses = val ?? false);
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Approve Expense Claims',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'CRUCIAL',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Member receives claim notifications and can approve/reject expense claims for this project.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'Granular Capabilities',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),

                        _buildPermCheckbox(
                          'View Budget & Cost Summary',
                          'Access financial overview, budget burn rate, and margins',
                          canViewBudget,
                          (v) => setSheetState(() => canViewBudget = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Record Project Revenue',
                          'Add revenue entries and invoice milestones',
                          canRecordRevenue,
                          (v) => setSheetState(() => canRecordRevenue = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'View Project Expenses',
                          'See expense receipts and transaction ledger',
                          canViewExpenses,
                          (v) => setSheetState(() => canViewExpenses = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Create Expenses for Project',
                          'Submit expense claims and upload receipts',
                          canCreateExpenses,
                          (v) => setSheetState(() => canCreateExpenses = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Manage Tasks & Milestones',
                          'Create, assign, and update task status',
                          canManageTasks,
                          (v) => setSheetState(() => canManageTasks = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Update Progress & Notes',
                          'Submit site progress updates and attach field photos',
                          canUpdateProgress,
                          (v) => setSheetState(() => canUpdateProgress = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Manage Team & Roles',
                          'Assign team members and grant granular access',
                          canManageTeam,
                          (v) => setSheetState(() => canManageTeam = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'Edit Project Details',
                          'Edit description, status, geofence, and client details',
                          canEditProject,
                          (v) => setSheetState(() => canEditProject = v),
                          isDark,
                        ),
                        _buildPermCheckbox(
                          'View Attendance & Geofence',
                          'View check-in logs and GPS verification status',
                          canViewAttendance,
                          (v) => setSheetState(() => canViewAttendance = v),
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getPrimary(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setSheetState(() => isSaving = true);
                                  final newPerms = ProjectPermissions(
                                    canViewBudget: canViewBudget,
                                    canRecordRevenue: canRecordRevenue,
                                    canViewExpenses: canViewExpenses,
                                    canCreateExpenses: canCreateExpenses,
                                    canApproveExpenses: canApproveExpenses,
                                    canManageTasks: canManageTasks,
                                    canUpdateProgress: canUpdateProgress,
                                    canManageTeam: canManageTeam,
                                    canEditProject: canEditProject,
                                    canViewAttendance: canViewAttendance,
                                  );

                                  final roleText = roleController.text.trim();
                                  final finalRole = roleText.isEmpty ? 'Member' : roleText;

                                  await ref.read(projectProvider.notifier).updateMemberRoleAndPermissions(
                                    project.id,
                                    userId: member.id,
                                    roleInProject: finalRole,
                                    permissions: newPerms,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(modalCtx);
                                    NotificationBanner.showSuccess(
                                      context,
                                      'Updated permissions for ${member.name} on ${project.name}.',
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Project Access', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermCheckbox(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
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
                                leading: AppAvatar(
                                  imageUrl: u.avatarUrl,
                                  name: u.name,
                                  size: 40,
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
                                    ),
                                    Text(
                                      u.email,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                      ),
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
