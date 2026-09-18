import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum ChipType {
  pending,
  approved,
  rejected,
  atRisk,
  profitable,
  lossMaking,
  completed,
  custom,
}

class StatusChip extends StatelessWidget {
  final String label;
  final ChipType type;
  final Color? customBackgroundColor;
  final Color? customTextColor;
  final Color? customBorderColor;
  final Color? customDotColor;

  const StatusChip({
    super.key,
    required this.label,
    Color? backgroundColor,
    Color? textColor,
    Color? borderColor,
    Color? dotColor,
  })  : type = ChipType.custom,
        customBackgroundColor = backgroundColor,
        customTextColor = textColor,
        customBorderColor = borderColor,
        customDotColor = dotColor;

  const StatusChip._internal({
    required this.label,
    required this.type,
  })  : customBackgroundColor = null,
        customTextColor = null,
        customBorderColor = null,
        customDotColor = null;

  factory StatusChip.fromExpenseStatus(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return const StatusChip._internal(
          label: 'Pending',
          type: ChipType.pending,
        );
      case ExpenseStatus.approved:
        return const StatusChip._internal(
          label: 'Approved',
          type: ChipType.approved,
        );
      case ExpenseStatus.rejected:
        return const StatusChip._internal(
          label: 'Rejected',
          type: ChipType.rejected,
        );
    }
  }

  factory StatusChip.atRisk() {
    return const StatusChip._internal(
      label: 'At Risk (>80%)',
      type: ChipType.atRisk,
    );
  }

  factory StatusChip.profitable({bool isProfitable = true}) {
    return StatusChip._internal(
      label: isProfitable ? 'Profitable' : 'Loss-Making',
      type: isProfitable ? ChipType.profitable : ChipType.lossMaking,
    );
  }

  factory StatusChip.completed() {
    return const StatusChip._internal(
      label: 'Completed',
      type: ChipType.completed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    Color bg;
    Color text;
    Color border;
    Color dot;

    switch (type) {
      case ChipType.pending:
        bg = isDark ? AppColors.darkAmberLight : AppColors.amberLight;
        text = isDark ? AppColors.amberAccent : AppColors.amberDark;
        border = isDark ? AppColors.darkAmberBorder : AppColors.amberBorder;
        dot = isDark ? AppColors.amberAccent : AppColors.amber;
        break;
      case ChipType.approved:
      case ChipType.profitable:
        bg = isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
        text = isDark ? AppColors.emeraldAccent : AppColors.emeraldDark;
        border = isDark ? AppColors.darkEmeraldBorder : AppColors.emeraldBorder;
        dot = isDark ? AppColors.emeraldAccent : AppColors.emeraldAccent;
        break;
      case ChipType.rejected:
      case ChipType.atRisk:
      case ChipType.lossMaking:
        bg = isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight;
        text = isDark ? AppColors.crimsonAccent : AppColors.crimsonDark;
        border = isDark ? AppColors.darkCrimsonBorder : AppColors.crimsonBorder;
        dot = isDark ? AppColors.crimsonAccent : AppColors.crimson;
        break;
      case ChipType.completed:
        bg = isDark ? AppColors.darkIndigoLight : AppColors.indigoLight;
        text = isDark ? AppColors.indigoAccent : AppColors.indigoDark;
        border = isDark ? AppColors.darkIndigoBorder : AppColors.indigoBorder;
        dot = isDark ? AppColors.indigoAccent : AppColors.indigo;
        break;
      case ChipType.custom:
        bg = customBackgroundColor ?? AppColors.getSurfaceSubtle(context);
        text = customTextColor ?? AppColors.getTextPrimary(context);
        border = customBorderColor ?? AppColors.getBorder(context);
        dot = customDotColor ?? AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
