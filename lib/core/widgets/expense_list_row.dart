import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'status_chip.dart';

class _CategoryTheme {
  final IconData icon;
  final Color accent;
  final Color lightBg;

  const _CategoryTheme(this.icon, this.accent, this.lightBg);
}

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

  _CategoryTheme _getCategoryTheme(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'travel':
      case 'flight':
        return const _CategoryTheme(
          Icons.flight_takeoff_rounded,
          Color(0xFF0284C7), // Sky Blue
          Color(0xFFE0F2FE),
        );
      case 'transport':
      case 'taxi':
        return const _CategoryTheme(
          Icons.local_taxi_rounded,
          Color(0xFF0D9488), // Teal
          Color(0xFFCCFBF1),
        );
      case 'meal':
      case 'food':
        return const _CategoryTheme(
          Icons.restaurant_rounded,
          Color(0xFFF97316), // Peach / Warm Coral
          Color(0xFFFFEDD5),
        );
      case 'lodging':
      case 'hotel':
        return const _CategoryTheme(
          Icons.hotel_rounded,
          Color(0xFF8B5CF6), // Soft Violet
          Color(0xFFF3E8FF),
        );
      case 'hardware':
      case 'tech':
        return const _CategoryTheme(
          Icons.laptop_mac_rounded,
          Color(0xFF10B981), // Emerald
          Color(0xFFDCFCE7),
        );
      case 'software':
      case 'subscription':
        return const _CategoryTheme(
          Icons.apps_rounded,
          Color(0xFF6366F1), // Indigo
          Color(0xFFEEF2FF),
        );
      case 'office':
      case 'supplies':
        return const _CategoryTheme(
          Icons.business_center_rounded,
          Color(0xFFD97706), // Warm Amber
          Color(0xFFFEF3C7),
        );
      default:
        return const _CategoryTheme(
          Icons.receipt_long_rounded,
          Color(0xFF4F46E5), // Royal Indigo
          Color(0xFFEEF2FF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catTheme = _getCategoryTheme(expense.categoryIcon);
    final iconBg = isDark ? catTheme.accent.withValues(alpha: 0.16) : catTheme.lightBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Category Squircle Icon with soft tinted pastel background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        catTheme.icon,
                        size: 21,
                        color: catTheme.accent,
                      ),
                      if (expense.receiptPhotoUrl != null && expense.receiptPhotoUrl!.isNotEmpty)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.attach_file_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Title, Category, Project, Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        showEmployeeName ? expense.employeeName : expense.projectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showEmployeeName
                            ? '${expense.projectName} • ${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}'
                            : '${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (expense.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          expense.note,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Amount + StatusChip or Trailing Action
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(expense.amount, currency: expense.currency),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
