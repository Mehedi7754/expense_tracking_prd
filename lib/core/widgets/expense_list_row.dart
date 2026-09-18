import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'status_chip.dart';

class ExpenseListRow extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  final Widget? trailingAction;
  final bool showEmployeeName;

  const ExpenseListRow({
    super.key,
    required this.expense,
    required this.onTap,
    this.trailingAction,
    this.showEmployeeName = false,
  });

  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'travel':
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'meal':
      case 'food':
        return Icons.restaurant_rounded;
      case 'lodging':
      case 'hotel':
        return Icons.hotel_rounded;
      case 'hardware':
      case 'tech':
        return Icons.laptop_mac_rounded;
      case 'software':
      case 'subscription':
        return Icons.apps_rounded;
      case 'transport':
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'office':
      case 'supplies':
        return Icons.business_center_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context), width: 1),
        boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Category Icon with subtle container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _getCategoryIcon(expense.categoryIcon),
                        size: 21,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      if (expense.receiptPhotoUrl != null && expense.receiptPhotoUrl!.isNotEmpty)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkEmeraldBorder : AppColors.emeraldBorder,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.attach_file_rounded,
                              size: 9,
                              color: isDark ? AppColors.emeraldAccent : AppColors.emeraldDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                // Title, Project, Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        showEmployeeName ? expense.employeeName : expense.projectName,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showEmployeeName
                            ? '${expense.projectName} • ${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}'
                            : '${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11.5,
                          color: AppColors.getTextMuted(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (expense.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          expense.note,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11.5,
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount + StatusChip or Trailing Action
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 95),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(expense.amount, currency: expense.currency),
                          style: AppTextStyles.currencySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (trailingAction != null)
                        trailingAction!
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusChip.fromExpenseStatus(expense.status),
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
