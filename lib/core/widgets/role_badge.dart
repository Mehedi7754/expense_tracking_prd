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
    final isDark = AppColors.isDark(context);
    Color bg;
    Color text;
    Color border;

    switch (role) {
      case UserRole.projectMember:
        bg = isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
        text = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        border = isDark ? AppColors.darkBorder : AppColors.border;
        break;
      case UserRole.projectManager:
        bg = isDark ? AppColors.darkIndigoLight : AppColors.indigoLight;
        text = isDark ? AppColors.indigoAccent : AppColors.indigo;
        border = isDark ? AppColors.darkIndigoBorder : AppColors.indigoBorder;
        break;
      case UserRole.finance:
        bg = isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
        text = isDark ? AppColors.emeraldAccent : AppColors.emerald;
        border = isDark ? AppColors.darkEmeraldBorder : AppColors.emeraldBorder;
        break;
      case UserRole.mainAdmin:
        bg = isDark ? AppColors.darkPrimaryLight : AppColors.primarySubtle;
        text = isDark ? AppColors.darkPrimary : AppColors.primary;
        border = isDark ? AppColors.darkPrimary.withAlpha(80) : AppColors.primary.withAlpha(40);
        break;
      case UserRole.viewer:
        bg = isDark ? const Color(0xFF1E3A8A).withAlpha(40) : Colors.blue.withAlpha(20);
        text = isDark ? const Color(0xFF93C5FD) : Colors.blue.shade700;
        border = isDark ? const Color(0xFF1D4ED8).withAlpha(70) : Colors.blue.withAlpha(60);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        role.displayName,
        style: (compact ? AppTextStyles.labelSmall : AppTextStyles.labelMedium).copyWith(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
