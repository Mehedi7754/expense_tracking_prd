import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense_model.dart';
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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: teamMembers.length,
        itemBuilder: (ctx, i) {
          final member = teamMembers[i];

          // Individual spend total for this project (PRD Section 4.4)
          double spend = 0.0;
          for (final exp in approvedExpenses.where((e) => e.employeeId == member.id)) {
            spend += exp.amount;
          }

          return InkWell(
            onTap: () => context.push('/profile/employee/${member.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(context)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
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
                        Text(member.name, style: AppTextStyles.titleSmall),
                        const SizedBox(height: 2),
                        Text('${member.department} • ${member.role.displayName}', style: AppTextStyles.bodySmall),
                        Text(
                          member.email,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.getTextMuted(context)),
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
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTextMuted(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
