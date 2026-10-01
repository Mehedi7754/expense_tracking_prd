import 'package:flutter/material.dart';
import '../../models/project_model.dart';

/// Visual status indicator badge based on project progress:
/// - **Not Started** (0%)
/// - **In Progress** (1%–74%)
/// - **Near Completion** (75%–99%)
/// - **Completed** (100%)
class ProjectProgressBadge extends StatelessWidget {
  final ProjectProgressStage stage;
  final double? percentage;
  final bool compact;
  final bool showPercentage;

  const ProjectProgressBadge({
    super.key,
    required this.stage,
    this.percentage,
    this.compact = false,
    this.showPercentage = true,
  });

  factory ProjectProgressBadge.fromProject(
    ProjectModel project, {
    bool compact = false,
    bool showPercentage = true,
  }) {
    return ProjectProgressBadge(
      stage: project.progressStage,
      percentage: project.progressPercentage,
      compact: compact,
      showPercentage: showPercentage,
    );
  }

  factory ProjectProgressBadge.fromPercentage(
    double percentage, {
    bool compact = false,
    bool showPercentage = true,
  }) {
    ProjectProgressStage stage;
    if (percentage <= 0.0) {
      stage = ProjectProgressStage.notStarted;
    } else if (percentage < 75.0) {
      stage = ProjectProgressStage.inProgress;
    } else if (percentage < 100.0) {
      stage = ProjectProgressStage.nearCompletion;
    } else {
      stage = ProjectProgressStage.completed;
    }
    return ProjectProgressBadge(
      stage: stage,
      percentage: percentage,
      compact: compact,
      showPercentage: showPercentage,
    );
  }

  Color _getColor(BuildContext context) {
    if (percentage != null) {
      final p = percentage!.clamp(0.0, 100.0);
      if (p <= 25.0) return const Color(0xFFEF4444); // Red: 0 to 25%
      if (p < 75.0) return const Color(0xFFF59E0B); // Amber/Orange: 26 to 74%
      if (p < 100.0) return const Color(0xFF3B82F6); // Blue: 75 to 99%
      return const Color(0xFF10B981); // Emerald Green: 100%
    }
    switch (stage) {
      case ProjectProgressStage.notStarted:
        return const Color(0xFFEF4444); // Red: 0 to 25%
      case ProjectProgressStage.inProgress:
        return const Color(0xFFF59E0B); // Amber / Orange: 26 to 74%
      case ProjectProgressStage.nearCompletion:
        return const Color(0xFF3B82F6); // Blue: 75 to 99%
      case ProjectProgressStage.completed:
        return const Color(0xFF10B981); // Emerald: 100%
    }
  }

  IconData _getIcon() {
    switch (stage) {
      case ProjectProgressStage.notStarted:
        return Icons.pending_actions_rounded;
      case ProjectProgressStage.inProgress:
        return Icons.sync_rounded;
      case ProjectProgressStage.nearCompletion:
        return Icons.trending_up_rounded;
      case ProjectProgressStage.completed:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColor(context);
    final icon = _getIcon();

    final label = stage.displayName;
    final pctText = percentage != null ? ' (${percentage!.toStringAsFixed(0)}%)' : '';
    final displayText = showPercentage && percentage != null ? '$label$pctText' : label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 35 : 22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withAlpha(isDark ? 80 : 50),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: compact ? 10 : 13,
            color: color,
          ),
          SizedBox(width: compact ? 3 : 4),
          Flexible(
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
