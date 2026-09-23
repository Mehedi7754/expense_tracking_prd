import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';

class ProjectCostCard extends StatelessWidget {
  final ProjectModel project;
  final List<ExpenseModel> projectExpenses;
  final VoidCallback? onTap;

  const ProjectCostCard({
    super.key,
    required this.project,
    required this.projectExpenses,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Financial calculations
    final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final officeBenefit = directCost * project.officeBenefitRate;
    final costIncurred = directCost + officeBenefit;
    final expectedRemaining = project.estimatedRemainingCost;
    final projectedFinalCost = costIncurred + expectedRemaining;
    final projectedProfit = project.grossProjectValue - projectedFinalCost;
    final projectedMargin = project.grossProjectValue > 0
        ? (projectedProfit / project.grossProjectValue) * 100
        : 0.0;

    // Budget utilization
    final totalBudget = project.budget > 0 ? project.budget : (project.grossProjectValue * 0.85);
    final budgetRatio = totalBudget > 0 ? (costIncurred / totalBudget) : 0.0;
    final isOverBudget = costIncurred > totalBudget;
    final isApproachingBudget = budgetRatio >= 0.80 && !isOverBudget;

    // Status colors (inspired by minimal reference designs)
    Color statusColor;
    Color statusBg;
    String statusLabel;

    if (isOverBudget) {
      statusColor = const Color(0xFFEF4444); // Soft Rose
      statusBg = const Color(0xFFFEF2F2);
      statusLabel = 'Over Budget';
    } else if (isApproachingBudget) {
      statusColor = const Color(0xFFF59E0B); // Soft Amber
      statusBg = const Color(0xFFFFFBEB);
      statusLabel = 'Near Limit';
    } else {
      statusColor = const Color(0xFF10B981); // Soft Emerald
      statusBg = const Color(0xFFECFDF5);
      statusLabel = '${projectedMargin.toStringAsFixed(1)}% Margin';
    }

    if (isDark) {
      statusBg = statusColor.withAlpha(25);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Project Title & Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Second row: Client Name & Gross Value
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        project.client,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(project.grossProjectValue, compact: true),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
