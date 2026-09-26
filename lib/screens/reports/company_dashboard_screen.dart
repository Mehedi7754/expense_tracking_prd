import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/chart_widget.dart';
import '../../core/widgets/project_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/expense_model.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';

class CompanyDashboardScreen extends ConsumerWidget {
  const CompanyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);

    // Company-wide total cost (approved expenses)
    double totalCompanyCost = 0.0;
    for (final exp in allExpenses.where((e) => e.status == ExpenseStatus.approved)) {
      totalCompanyCost += exp.amount;
    }

    // Company-wide total revenue
    double totalCompanyRevenue = 0.0;
    for (final proj in allProjects) {
      for (final rev in proj.revenueEntries) {
        totalCompanyRevenue += rev.amount;
      }
    }

    final totalCompanyProfit = totalCompanyRevenue - totalCompanyCost;

    // Highest-spending projects (sorted descending by spent)
    final projectSpendList = allProjects.map((p) {
      double spent = 0.0;
      for (final e in allExpenses.where((exp) => exp.projectId == p.id && exp.status == ExpenseStatus.approved)) {
        spent += e.amount;
      }
      double rev = 0.0;
      for (final r in p.revenueEntries) {
        rev += r.amount;
      }
      return {'project': p, 'spent': spent, 'revenue': rev};
    }).toList();

    projectSpendList.sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));

    // Projects at risk (>80% budget consumed) (PRD Section 4.5)
    final atRiskProjects = projectSpendList.where((item) {
      final p = item['project'] as dynamic;
      final spent = item['spent'] as double;
      return p.budget > 0 && (spent / p.budget) >= 0.80;
    }).toList();

    // Top Expense Categories Company-Wide (PRD Section 4.5)
    final Map<String, double> categoryRollup = {};
    for (final exp in allExpenses.where((e) => e.status == ExpenseStatus.approved)) {
      categoryRollup[exp.categoryName] = (categoryRollup[exp.categoryName] ?? 0.0) + exp.amount;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Company Financial Overview'),
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
            // Company-wide Totals (PRD Section 4.5: Revenue, Cost, Profit)
            Text('Enterprise Financial Performance', style: AppTextStyles.titleSmall),
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
                  label: 'Company Revenue',
                  value: CurrencyFormatter.format(totalCompanyRevenue, compact: true),
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.emerald,
                  iconBgColor: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
                ),
                StatCard(
                  label: 'Total Expenses',
                  value: CurrencyFormatter.format(totalCompanyCost, compact: true),
                  icon: Icons.credit_card_rounded,
                  iconColor: AppColors.getPrimary(context),
                  iconBgColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                ),
                StatCard(
                  label: 'Net Profit',
                  value: CurrencyFormatter.format(totalCompanyProfit, compact: true),
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: totalCompanyProfit >= 0 ? AppColors.emerald : AppColors.crimson,
                  iconBgColor: totalCompanyProfit >= 0
                      ? (isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight)
                      : (isDark ? AppColors.crimsonDark.withValues(alpha: 0.3) : AppColors.crimsonLight),
                  trendDirection: totalCompanyProfit >= 0 ? TrendDirection.up : TrendDirection.down,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Top Expense Categories Company-Wide (PRD Section 4.5)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(context)),
                boxShadow: isDark ? [] : AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Expense Categories Company-Wide', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 16),
                  CategoryDonutChart(categoryCosts: categoryRollup, total: totalCompanyCost),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Projects At Risk List (>80% of budget) (PRD Section 4.5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text('Projects at Budget Risk (>80%)', style: AppTextStyles.titleSmall),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.crimsonDark.withValues(alpha: 0.3) : AppColors.crimsonLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${atRiskProjects.length} Flagged',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDark ? const Color(0xFFFCA5A5) : AppColors.crimsonDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (atRiskProjects.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald, size: 20),
                    const SizedBox(width: 10),
                    Text('No projects currently breach the 80% threshold.', style: AppTextStyles.bodySmall),
                  ],
                ),
              )
            else
              ...atRiskProjects.map((item) {
                final p = item['project'] as dynamic;
                final spent = item['spent'] as double;
                final rev = item['revenue'] as double;
                return ProjectCard(
                  project: p,
                  spent: spent,
                  revenue: rev,
                  onTap: () => context.push('/projects/${p.id}'),
                );
              }),

            const SizedBox(height: 24),

            // Highest-Spending Projects List (PRD Section 4.5)
            Text('Highest-Spending Projects', style: AppTextStyles.titleSmall),
            const SizedBox(height: 10),
            ...projectSpendList.take(3).map((item) {
              final p = item['project'] as dynamic;
              final spent = item['spent'] as double;
              final rev = item['revenue'] as double;
              return ProjectCard(
                project: p,
                spent: spent,
                revenue: rev,
                onTap: () => context.push('/projects/${p.id}'),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
