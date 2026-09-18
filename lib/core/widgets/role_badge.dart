import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool compact;

  const RoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    switch (role) {
      case UserRole.employee:
        bg = AppColors.surfaceSubtle;
        text = AppColors.textSecondary;
        border = AppColors.border;
        break;
      case UserRole.manager:
        bg = AppColors.indigoLight;
        text = AppColors.indigo;
        border = AppColors.indigoBorder;
        break;
      case UserRole.finance:
        bg = AppColors.emeraldLight;
        text = AppColors.emerald;
        border = AppColors.emeraldBorder;
        break;
      case UserRole.admin:
        bg = AppColors.primarySubtle;
        text = AppColors.primary;
        border = AppColors.border;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        role.displayName,
        style: (compact ? AppTextStyles.labelSmall : AppTextStyles.labelMedium).copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
