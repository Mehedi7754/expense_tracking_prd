import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/image_utils.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import 'project_progress_badge.dart';

class _CardPalette {
  final Color accent;
  final Color lightBg;
  final IconData icon;

  const _CardPalette({
    required this.accent,
    required this.lightBg,
    required this.icon,
  });
}

class ProjectCostCard extends StatelessWidget {
  final ProjectModel project;
  final List<ExpenseModel> projectExpenses;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EdgeInsetsGeometry? margin;
  final bool showFinancials;

  const ProjectCostCard({
    super.key,
    required this.project,
    required this.projectExpenses,
    this.onTap,
    this.onDelete,
    this.margin,
    this.showFinancials = true,
  });

  static const List<_CardPalette> _curatedPalettes = [
    _CardPalette(
      accent: Color(0xFFF97316), // Peach / Warm Coral
      lightBg: Color(0xFFFFEDD5),
      icon: CupertinoIcons.briefcase_fill,
    ),
    _CardPalette(
      accent: Color(0xFF8B5CF6), // Soft Violet / Lavender
      lightBg: Color(0xFFF3E8FF),
      icon: CupertinoIcons.book_fill,
    ),
    _CardPalette(
      accent: Color(0xFF0284C7), // Sky Blue
      lightBg: Color(0xFFE0F2FE),
      icon: CupertinoIcons.building_2_fill,
    ),
    _CardPalette(
      accent: Color(0xFF10B981), // Fresh Mint Emerald
      lightBg: Color(0xFFDCFCE7),
      icon: CupertinoIcons.chart_bar_alt_fill,
    ),
    _CardPalette(
      accent: Color(0xFF6366F1), // Royal Indigo
      lightBg: Color(0xFFEEF2FF),
      icon: CupertinoIcons.layers_fill,
    ),
    _CardPalette(
      accent: Color(0xFFEC4899), // Soft Rose Pink
      lightBg: Color(0xFFFCE7F3),
      icon: CupertinoIcons.rocket_fill,
    ),
    _CardPalette(
      accent: Color(0xFF0D9488), // Ocean Teal
      lightBg: Color(0xFFCCFBF1),
      icon: CupertinoIcons.chart_pie_fill,
    ),
    _CardPalette(
      accent: Color(0xFFD97706), // Warm Amber
      lightBg: Color(0xFFFEF3C7),
      icon: CupertinoIcons.folder_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Financial calculations (Only approved expenses count towards expenditure)
    final validExpenses = projectExpenses.where((e) => e.status == ExpenseStatus.approved);
    final directCost = validExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final costIncurred = directCost;
    final totalBudget = project.grossProjectValue > 0 ? project.grossProjectValue : project.budget;
    final budgetRatio = totalBudget > 0 ? (costIncurred / totalBudget) : 0.0;
    final isOverBudget = costIncurred > totalBudget && totalBudget > 0;
    final isApproachingBudget = budgetRatio >= 0.80 && !isOverBudget;
    final isCompleted = project.status == ProjectStatus.completed;

    // Pick Palette
    final int hash = project.id.hashCode.abs();
    final defaultPalette = _curatedPalettes[hash % _curatedPalettes.length];

    Color accentColor;
    Color iconBg;
    IconData iconData;

    if (isCompleted) {
      accentColor = const Color(0xFF10B981);
      iconBg = isDark ? accentColor.withValues(alpha: 0.16) : const Color(0xFFDCFCE7);
      iconData = Icons.task_alt_rounded;
    } else if (isOverBudget) {
      accentColor = const Color(0xFFEF4444);
      iconBg = isDark ? accentColor.withValues(alpha: 0.16) : const Color(0xFFFEE2E2);
      iconData = Icons.warning_amber_rounded;
    } else if (isApproachingBudget) {
      accentColor = const Color(0xFFF59E0B);
      iconBg = isDark ? accentColor.withValues(alpha: 0.16) : const Color(0xFFFEF3C7);
      iconData = Icons.trending_up_rounded;
    } else {
      accentColor = defaultPalette.accent;
      iconBg = isDark ? accentColor.withValues(alpha: 0.16) : defaultPalette.lightBg;
      iconData = defaultPalette.icon;
    }

    final Color trackColor = isDark
        ? accentColor.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.12);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left squircle icon / thumbnail
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.20),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: (project.imageUrl != null && project.imageUrl!.isNotEmpty)
                        ? _buildProjectThumbnail(project.imageUrl!, iconData, accentColor)
                        : Center(
                            child: Icon(
                              iconData,
                              size: 22,
                              color: accentColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Middle Column: Info & Linear Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    project.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (showFinancials)
                            Text(
                              CurrencyFormatter.format(costIncurred, compact: true),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                fontSize: 14,
                                letterSpacing: -0.3,
                              ),
                            )
                          else
                            ProjectProgressBadge.fromProject(project, compact: true, showPercentage: false),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            project.projectId,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                          if (project.client.isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                ' • ${project.client}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GFProgressBar(
                              percentage: ((isCompleted || project.progressPercentage >= 100.0)
                                  ? 1.0
                                  : (project.progressPercentage.clamp(0.0, 100.0) / 100.0)).clamp(0.0, 1.0),
                              lineHeight: 5,
                              backgroundColor: trackColor,
                              progressBarColor: accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (isCompleted || project.progressPercentage >= 100.0)
                                ? '100%'
                                : '${project.progressPercentage.clamp(0.0, 100.0).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Right: Delete Action (optional)
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
                    tooltip: 'Delete Project',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectThumbnail(String path, IconData fallbackIcon, Color fallbackColor) {
    return AppImageHelper.buildImage(
      path: path,
      width: 44,
      height: 44,
      placeholder: () => Center(child: Icon(fallbackIcon, size: 22, color: fallbackColor)),
    );
  }
}


