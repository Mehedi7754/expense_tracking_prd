import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import 'notification_banner.dart';
import 'project_progress_badge.dart';

/// Modal dialog allowing Admin and Manager users to update project progress
/// using an interactive slider (0%–100%) and preset buttons.
class UpdateProgressDialog extends ConsumerStatefulWidget {
  final ProjectModel project;

  const UpdateProgressDialog({
    super.key,
    required this.project,
  });

  static Future<void> show(BuildContext context, ProjectModel project) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateProgressDialog(project: project),
    );
  }

  @override
  ConsumerState<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends ConsumerState<UpdateProgressDialog> {
  late double _progress;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.project.progressPercentage.clamp(0.0, 100.0);
  }

  Future<void> _saveProgress() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    await ref.read(projectProvider.notifier).updateProjectProgress(
          projectId: widget.project.id,
          progressPercentage: _progress,
          updatedById: user.id,
          updatedByName: user.name,
        );

    if (mounted) {
      Navigator.of(context).pop();

      NotificationBanner.showSuccess(
        context,
        'Project progress updated to ${_progress.toStringAsFixed(0)}% (${widget.project.name})',
      );
    }
  }

  Color _getProgressColor(double pct) {
    if (pct <= 25.0) return const Color(0xFFEF4444); // Red: 0 to 25%
    if (pct < 75.0) return const Color(0xFFF59E0B); // Amber / Orange: 26 to 74%
    if (pct < 100.0) return const Color(0xFF3B82F6); // Blue: 75 to 99%
    return const Color(0xFF10B981); // Emerald Green: 100%
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getProgressColor(_progress);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.speed_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Project Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          widget.project.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Large Percentage Preview & Live Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${_progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: -1,
                          ),
                        ),
                        ProjectProgressBadge.fromPercentage(_progress),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Linear Animated Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress / 100.0,
                        minHeight: 10,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thumbColor: color,
                  overlayColor: color.withAlpha(35),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _progress,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${_progress.toStringAsFixed(0)}%',
                  onChanged: (val) {
                    setState(() => _progress = val.roundToDouble());
                  },
                ),
              ),

              // Quick Presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPresetChip(0, '0%'),
                  _buildPresetChip(25, '25%'),
                  _buildPresetChip(50, '50%'),
                  _buildPresetChip(75, '75%'),
                  _buildPresetChip(100, '100%'),
                ],
              ),

              const SizedBox(height: 16),

              // Last update audit info
              if (widget.project.progressUpdatedAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Last updated: ${DateFormatter.formatDateTime(widget.project.progressUpdatedAt!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProgress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Save Progress',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(double val, String label) {
    final isSelected = _progress == val;
    final color = _getProgressColor(val);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _progress = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
