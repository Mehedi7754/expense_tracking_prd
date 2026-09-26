import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';

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
  final EdgeInsetsGeometry? margin;

  const ProjectCostCard({
    super.key,
    required this.project,
    required this.projectExpenses,
    this.onTap,
    this.margin,
  });

  static const List<_CardPalette> _curatedPalettes = [
    _CardPalette(
      accent: Color(0xFFF97316), // Peach / Warm Coral
      lightBg: Color(0xFFFFEDD5),
      icon: Icons.business_center_rounded,
    ),
    _CardPalette(
      accent: Color(0xFF8B5CF6), // Soft Violet / Lavender
      lightBg: Color(0xFFF3E8FF),
      icon: Icons.school_rounded,
    ),
    _CardPalette(
      accent: Color(0xFF0284C7), // Sky Blue
      lightBg: Color(0xFFE0F2FE),
      icon: Icons.domain_rounded,
    ),
    _CardPalette(
      accent: Color(0xFF10B981), // Fresh Mint Emerald
      lightBg: Color(0xFFDCFCE7),
      icon: Icons.analytics_rounded,
    ),
    _CardPalette(
      accent: Color(0xFF6366F1), // Royal Indigo
      lightBg: Color(0xFFEEF2FF),
      icon: Icons.layers_rounded,
    ),
    _CardPalette(
      accent: Color(0xFFEC4899), // Soft Rose Pink
      lightBg: Color(0xFFFCE7F3),
      icon: Icons.rocket_launch_rounded,
    ),
    _CardPalette(
      accent: Color(0xFF0D9488), // Ocean Teal
      lightBg: Color(0xFFCCFBF1),
      icon: Icons.pie_chart_rounded,
    ),
    _CardPalette(
      accent: Color(0xFFD97706), // Warm Amber
      lightBg: Color(0xFFFEF3C7),
      icon: Icons.folder_special_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Financial calculations
    final directCost = projectExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final officeBenefit = directCost * project.officeBenefitRate;
    final costIncurred = directCost + officeBenefit;
    final totalBudget = project.budget > 0 ? project.budget : (project.grossProjectValue * 0.85);
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

    final displayPercent = (budgetRatio * 100).round();

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                // 1. Left squircle icon with soft tinted pastel background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      size: 27,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 15),

                // 2. Middle Column: Project Name & Minimal Financials
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${CurrencyFormatter.format(costIncurred, compact: true)} ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                fontSize: 13.5,
                              ),
                            ),
                            TextSpan(
                              text: 'of ${CurrencyFormatter.format(totalBudget, compact: true)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Right: Sleek Circular Progress Ring with Percentage
                _MinimalCircularProgress(
                  progress: isCompleted ? 1.0 : budgetRatio,
                  color: accentColor,
                  trackColor: trackColor,
                  label: isCompleted ? '100%' : '$displayPercent%',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalCircularProgress extends StatelessWidget {
  final double progress;
  final Color color;
  final Color trackColor;
  final String label;

  const _MinimalCircularProgress({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          trackColor: trackColor,
          strokeWidth: 4.5,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label.length > 3 ? 11.5 : 13.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // 12 o'clock
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
