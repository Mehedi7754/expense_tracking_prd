import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import 'budget_progress_bar.dart';
import 'status_chip.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final double spent;
  final double revenue;
  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.project,
    required this.spent,
    required this.revenue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final double profit = revenue - spent;
    final bool isProfitable = profit >= 0;
    final double percentUsed = project.budget > 0 ? (spent / project.budget) : 0.0;
    final bool isAtRisk = percentUsed >= 0.80;

    final borderColor = isAtRisk
        ? (isDark ? AppColors.darkCrimsonBorder : AppColors.crimsonBorder)
        : AppColors.getBorder(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isAtRisk ? 1.2 : 1,
        ),
        boxShadow: isDark
            ? AppColors.darkCardShadow(isAtRisk ? AppColors.crimson : null)
            : AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Project Name, Client, Status Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.business_center_rounded,
                        size: 19,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 15.5,
                              color: AppColors.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            project.client,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isAtRisk)
                      StatusChip.atRisk()
                    else
                      StatusChip.profitable(isProfitable: isProfitable),
                  ],
                ),
                const SizedBox(height: 14),
                // Budget Progress Bar
                BudgetProgressBar(
                  budget: project.budget,
                  spent: spent,
                  showLabels: true,
                  height: 6,
                ),
                const SizedBox(height: 14),
                // Financial summary breakdown row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FinancialMetric(
                        label: 'Budget',
                        value: CurrencyFormatter.format(project.budget, compact: true),
                      ),
                      _FinancialMetric(
                        label: 'Spent',
                        value: CurrencyFormatter.format(spent, compact: true),
                      ),
                      _FinancialMetric(
                        label: 'Revenue',
                        value: CurrencyFormatter.format(revenue, compact: true),
                      ),
                      _FinancialMetric(
                        label: 'Profit',
                        value: CurrencyFormatter.format(profit, compact: true),
                        valueColor: isProfitable
                            ? (isDark ? AppColors.emeraldAccent : AppColors.emeraldDark)
                            : (isDark ? AppColors.crimsonAccent : AppColors.crimson),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _FinancialMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 10,
            color: AppColors.getTextMuted(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.currencySmall.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.getTextPrimary(context),
          ),
        ),
      ],
    );
  }
}
