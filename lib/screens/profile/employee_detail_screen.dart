import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/chart_widget.dart';
import '../../core/widgets/expense_list_row.dart';
import '../../core/widgets/role_badge.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../state/expense_provider.dart';
import '../../state/user_management_provider.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UserModel> allUsers = ref.watch(userManagementProvider);
    final List<ExpenseModel> allExpenses = ref.watch(expenseProvider);
    final bool isDark = AppColors.isDark(context);

    final Iterable<UserModel> match = allUsers.where((UserModel u) => u.id == employeeId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Employee Profile')),
        body: const Center(child: Text('Employee not found')),
      );
    }

    final UserModel employee = match.first;

    // Expenses for this employee
    final List<ExpenseModel> empExpenses =
        allExpenses.where((ExpenseModel e) => e.employeeId == employee.id).toList();
    final List<ExpenseModel> approved =
        empExpenses.where((ExpenseModel e) => e.status == ExpenseStatus.approved).toList();
    final List<ExpenseModel> rejected =
        empExpenses.where((ExpenseModel e) => e.status == ExpenseStatus.rejected).toList();

    double totalSpend = 0.0;
    for (final ExpenseModel e in approved) {
      totalSpend += e.amount;
    }

    // Spend broken down by category (PRD Section 4.4)
    final Map<String, double> categoryBreakdown = <String, double>{};
    for (final ExpenseModel e in approved) {
      categoryBreakdown[e.categoryName] =
          (categoryBreakdown[e.categoryName] ?? 0.0) + e.amount;
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(employee.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.getBorder(context)),
                boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    child: Text(
                      employee.name.isNotEmpty ? employee.name[0] : 'U',
                      style: AppTextStyles.displayMedium.copyWith(
                        fontSize: 24,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                employee.name,
                                style: AppTextStyles.titleMedium.copyWith(color: AppColors.getTextPrimary(context)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            RoleBadge(role: employee.role, compact: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          employee.email,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextSecondary(context)),
                        ),
                        Text(
                          employee.department,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Spend Overview Metrics
            Text('Spend Across All Projects', style: AppTextStyles.titleSmall),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                StatCard(
                  label: 'Approved Spend',
                  value: CurrencyFormatter.format(totalSpend, compact: true),
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.emerald,
                  iconBgColor: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
                ),
                StatCard(
                  label: 'Approved Claims',
                  value: '${approved.length}',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.emerald,
                  iconBgColor: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
                ),
                StatCard(
                  label: 'Rejected Claims',
                  value: '${rejected.length}',
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.crimson,
                  iconBgColor: isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Cost Broken Down by Category Chart (PRD Section 4.4)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(context)),
                boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spend by Category', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 16),
                  CategoryDonutChart(categoryCosts: categoryBreakdown, total: totalSpend),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // History of Approved and Rejected Expenses (PRD Section 4.4)
            Text('Approved & Rejected History', style: AppTextStyles.titleSmall),
            const SizedBox(height: 10),
            ...<ExpenseModel>[...approved, ...rejected].map((e) => ExpenseListRow(
                  expense: e,
                  onTap: () => context.push('/expenses/${e.id}'),
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
