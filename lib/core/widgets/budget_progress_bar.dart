import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class BudgetProgressBar extends StatelessWidget {
  final double budget;
  final double spent;
  final bool showLabels;
  final double height;

  const BudgetProgressBar({
    super.key,
    required this.budget,
    required this.spent,
    this.showLabels = true,
    this.height = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final double percentage = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : (spent > 0 ? 1.0 : 0.0);
    final double rawPercent = budget > 0 ? (spent / budget) : (spent > 0 ? 1.0 : 0.0);
    final bool isOverBudget = spent > budget;
    final bool isAtRisk = rawPercent >= 0.80 && !isOverBudget;

    LinearGradient progressGradient;
    Color statusColor;

    if (isOverBudget) {
      progressGradient = AppColors.crimsonGradient;
      statusColor = isDark ? AppColors.crimsonAccent : AppColors.crimson;
    } else if (isAtRisk) {
      progressGradient = AppColors.amberGradient;
      statusColor = isDark ? AppColors.amberAccent : AppColors.amber;
    } else {
      progressGradient = AppColors.emeraldGradient;
      statusColor = isDark ? AppColors.emeraldAccent : AppColors.emerald;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Consumed',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.getTextMuted(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(isDark ? 30 : 20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withAlpha(isDark ? 70 : 45),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAtRisk || isOverBudget) ...[
                      Icon(
                        isOverBudget ? Icons.warning_rounded : Icons.info_outline_rounded,
                        size: 11,
                        color: statusColor,
                      ),
                      const SizedBox(width: 3.5),
                    ],
                    Text(
                      '${(rawPercent * 100).toStringAsFixed(1)}%',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              Container(
                height: height,
                width: double.infinity,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * percentage,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: progressGradient,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: (isAtRisk || isOverBudget)
                          ? [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
