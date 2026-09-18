import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/notification_model.dart';
import '../../state/auth_provider.dart';
import '../../state/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.expenseApproved:
        return Icons.check_circle_rounded;
      case NotificationType.expenseRejected:
        return Icons.cancel_rounded;
      case NotificationType.budgetWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.commentAdded:
        return Icons.chat_bubble_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.expenseApproved:
        return isDark ? AppColors.emeraldAccent : AppColors.emerald;
      case NotificationType.expenseRejected:
        return isDark ? AppColors.crimsonAccent : AppColors.crimson;
      case NotificationType.budgetWarning:
        return isDark ? AppColors.amberAccent : AppColors.amber;
      case NotificationType.commentAdded:
        return isDark ? AppColors.indigoAccent : AppColors.indigo;
      case NotificationType.general:
        return isDark ? AppColors.darkPrimary : AppColors.primary;
    }
  }

  Color _getBgColor(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.expenseApproved:
        return isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
      case NotificationType.expenseRejected:
        return isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight;
      case NotificationType.budgetWarning:
        return isDark ? AppColors.darkAmberLight : AppColors.amberLight;
      case NotificationType.commentAdded:
        return isDark ? AppColors.darkIndigoLight : AppColors.indigoLight;
      case NotificationType.general:
        return isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final user = ref.watch(authProvider).currentUser;
    final isDark = AppColors.isDark(context);

    // Filter notifications for current user or general
    final userNotifs = notifications.where((n) {
      if (user == null) return true;
      return n.userId == user.id || n.userId.isEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        actions: [
          if (userNotifs.any((n) => !n.isRead))
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: const Text('Mark All Read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: userNotifs.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications',
              message: 'You are all caught up! There are no alerts for your account right now.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: userNotifs.length,
              itemBuilder: (ctx, i) {
                final notif = userNotifs[i];
                final bgColor = notif.isRead
                    ? AppColors.getSurface(context)
                    : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle);

                final borderColor = notif.isRead
                    ? AppColors.getBorder(context)
                    : (isDark ? AppColors.darkPrimary.withValues(alpha: 0.5) : AppColors.primarySubtle);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: notif.isRead ? 1 : 1.4,
                    ),
                    boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _getBgColor(notif.type, isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIcon(notif.type),
                        color: _getIconColor(notif.type, isDark),
                        size: 22,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                              color: AppColors.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormatter.formatRelative(notif.timestamp),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.getTextMuted(context),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        notif.message,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: notif.isRead
                              ? AppColors.getTextMuted(context)
                              : AppColors.getTextSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: notif.isRead
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      ref.read(notificationProvider.notifier).markAsRead(notif.id);
                      context.push('/notifications/${notif.id}');
                    },
                  ),
                );
              },
            ),
    );
  }
}
