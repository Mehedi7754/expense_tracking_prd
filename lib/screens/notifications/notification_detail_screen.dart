import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/notification_model.dart';
import '../../state/notification_provider.dart';

class NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;

  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final notifList = notifications.where((n) => n.id == notificationId);
    final isDark = AppColors.isDark(context);

    if (notifList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Detail')),
        body: const Center(child: Text('Notification record not found.')),
      );
    }

    final notif = notifList.first;

    Color badgeBg = isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
    Color badgeTextColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    switch (notif.type) {
      case NotificationType.expenseRejected:
        badgeBg = isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight;
        badgeTextColor = isDark ? AppColors.crimsonAccent : AppColors.crimsonDark;
        break;
      case NotificationType.expenseApproved:
        badgeBg = isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
        badgeTextColor = isDark ? AppColors.emeraldAccent : AppColors.emeraldDark;
        break;
      case NotificationType.budgetWarning:
        badgeBg = isDark ? AppColors.darkAmberLight : AppColors.amberLight;
        badgeTextColor = isDark ? AppColors.amberAccent : AppColors.amberDark;
        break;
      case NotificationType.commentAdded:
        badgeBg = isDark ? AppColors.darkIndigoLight : AppColors.indigoLight;
        badgeTextColor = isDark ? AppColors.indigoAccent : AppColors.indigoDark;
        break;
      case NotificationType.general:
        badgeBg = isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
        badgeTextColor = isDark ? AppColors.darkPrimary : AppColors.primary;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Notification Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            notif.type.displayName,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: badgeTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormatter.formatRelative(notif.timestamp),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      notif.title,
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notif.message,
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),
                    Text(
                      'Full Context & Details',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notif.fullExplanation,
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.5,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Direct Link Navigation Button (PRD Section 4.2: Tapping notification opens relevant screen)
              if (notif.relatedExpenseId != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/expenses/${notif.relatedExpenseId}'),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('View Related Expense Claim'),
                  ),
                ),
              ],
              if (notif.relatedProjectId != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/projects/${notif.relatedProjectId}'),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('View Related Project'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
