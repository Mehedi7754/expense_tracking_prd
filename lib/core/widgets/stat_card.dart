import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum TrendDirection {
  up,
  down,
  neutral;
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? trendText;
  final TrendDirection trendDirection;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.iconBgColor,
    this.trendText,
    this.trendDirection = TrendDirection.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    Color trendTextColor;
    Color trendBgColor;
    IconData? trendIcon;

    switch (trendDirection) {
      case TrendDirection.up:
        trendTextColor = isDark ? AppColors.emeraldAccent : AppColors.emeraldDark;
        trendBgColor = isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
        trendIcon = Icons.trending_up_rounded;
        break;
      case TrendDirection.down:
        trendTextColor = isDark ? AppColors.crimsonAccent : AppColors.crimsonDark;
        trendBgColor = isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight;
        trendIcon = Icons.trending_down_rounded;
        break;
      case TrendDirection.neutral:
        trendTextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        trendBgColor = isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
        trendIcon = null;
        break;
    }

    final effectiveIconBg = iconBgColor ??
        (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle);
    final effectiveIconColor = iconColor ??
        (isDark ? AppColors.darkPrimary : AppColors.primary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
          boxShadow: isDark ? AppColors.darkCardShadow(iconColor) : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (icon != null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: effectiveIconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: effectiveIconColor,
                    ),
                  )
                else
                  const SizedBox(height: 32),
                if (trendText != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: trendBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (trendIcon != null) ...[
                            Icon(trendIcon, size: 10, color: trendTextColor),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              trendText!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: trendTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTextStyles.currencyLarge.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11,
                    color: AppColors.getTextMuted(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
