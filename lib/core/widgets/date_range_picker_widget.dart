import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/date_formatter.dart';

class DateRangePickerWidget extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onRangeSelected;

  const DateRangePickerWidget({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textWhite,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onRangeSelected(picked);
    }
  }

  void _selectPreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_30':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    onRangeSelected(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final String rangeText = selectedRange != null
        ? '${DateFormatter.formatShort(selectedRange!.start)} - ${DateFormatter.formatShort(selectedRange!.end)}'
        : 'All Time (No date filter)';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    rangeText,
                    style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (selectedRange != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onRangeSelected(null),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(
                  label: 'This Month',
                  onTap: () => _selectPreset('this_month'),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'Last 30 Days',
                  onTap: () => _selectPreset('last_30'),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'This Year',
                  onTap: () => _selectPreset('this_year'),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'Custom Range...',
                  isCustom: true,
                  onTap: () => _pickCustomRange(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isCustom;

  const _PresetChip({
    required this.label,
    required this.onTap,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isCustom ? AppColors.surfaceSubtle : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isCustom ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isCustom ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
