import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ApproveRejectDialog {
  ApproveRejectDialog._();

  static Future<String?> showRejectDialog(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.crimsonDark.withValues(alpha: 0.3) : AppColors.crimsonLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: AppColors.crimson, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(subtitle, style: AppTextStyles.bodySmall),
                const SizedBox(height: 14),
              ],
              Text(
                'Reason for Rejection *',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Missing receipt, exceeds travel policy limit...',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'A rejection reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  static Future<bool> showConfirmApprovalDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.emerald, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
