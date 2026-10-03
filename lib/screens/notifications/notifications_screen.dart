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
      case NotificationType.expenseSubmitted:
        return Icons.upload_file_rounded;
      case NotificationType.budgetWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.commentAdded:
        return Icons.chat_bubble_rounded;
      case NotificationType.attendanceReminder:
        return Icons.alarm_rounded;
      case NotificationType.attendanceLate:
        return Icons.schedule_rounded;
      case NotificationType.absenceDeducted:
        return Icons.event_busy_rounded;
      case NotificationType.salaryReady:
        return Icons.payments_rounded;
      case NotificationType.payrollFinalized:
        return Icons.account_balance_rounded;
      case NotificationType.revenueReceived:
        return Icons.trending_up_rounded;
      case NotificationType.memberAdded:
        return Icons.group_add_rounded;
      case NotificationType.userRegistration:
        return Icons.person_add_rounded;
      case NotificationType.securityAlert:
        return Icons.security_rounded;
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
      case NotificationType.expenseSubmitted:
        return isDark ? AppColors.indigoAccent : AppColors.indigo;
      case NotificationType.budgetWarning:
        return isDark ? AppColors.amberAccent : AppColors.amber;
      case NotificationType.commentAdded:
        return isDark ? AppColors.indigoAccent : AppColors.indigo;
      case NotificationType.attendanceReminder:
      case NotificationType.attendanceLate:
        return isDark ? AppColors.amberAccent : AppColors.amber;
      case NotificationType.absenceDeducted:
        return isDark ? AppColors.crimsonAccent : AppColors.crimson;
      case NotificationType.salaryReady:
      case NotificationType.payrollFinalized:
        return isDark ? AppColors.emeraldAccent : AppColors.emerald;
      case NotificationType.revenueReceived:
        return isDark ? AppColors.emeraldAccent : AppColors.emerald;
      case NotificationType.memberAdded:
      case NotificationType.userRegistration:
        return isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary;
      case NotificationType.securityAlert:
        return isDark ? AppColors.crimsonAccent : AppColors.crimson;
      case NotificationType.general:
        return isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary;
    }
  }

  Color _getBgColor(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.expenseApproved:
      case NotificationType.salaryReady:
      case NotificationType.payrollFinalized:
      case NotificationType.revenueReceived:
        return isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight;
      case NotificationType.expenseRejected:
      case NotificationType.absenceDeducted:
      case NotificationType.securityAlert:
        return isDark ? AppColors.darkCrimsonLight : AppColors.crimsonLight;
      case NotificationType.budgetWarning:
      case NotificationType.attendanceReminder:
      case NotificationType.attendanceLate:
        return isDark ? AppColors.darkAmberLight : AppColors.amberLight;
      case NotificationType.commentAdded:
      case NotificationType.expenseSubmitted:
        return isDark ? AppColors.darkIndigoLight : AppColors.indigoLight;
      case NotificationType.memberAdded:
      case NotificationType.userRegistration:
      case NotificationType.general:
        return isDark ? AppColors.brandPrimary.withAlpha(40) : AppColors.brandPrimary.withAlpha(20);
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

    final hasUnread = userNotifs.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${userNotifs.where((n) => !n.isRead).length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: Text(
                'Mark All Read',
                style: TextStyle(
                  color: isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (userNotifs.isNotEmpty)
            IconButton(
              tooltip: 'Delete All',
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: isDark ? AppColors.crimsonAccent : AppColors.crimson,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete All Notifications'),
                    content: const Text(
                      'This will permanently delete all your notifications. Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.crimson,
                        ),
                        child: const Text('Delete All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(notificationProvider.notifier).deleteAll();
                }
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: userNotifs.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications',
              message: 'You are all caught up! There are no alerts for your account right now.',
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: userNotifs.length,
                itemBuilder: (ctx, i) {
                  final notif = userNotifs[i];
                  return _NotificationCard(
                    notif: notif,
                    isDark: isDark,
                    icon: _getIcon(notif.type),
                    iconColor: _getIconColor(notif.type, isDark),
                    bgColor: _getBgColor(notif.type, isDark),
                    onDelete: () =>
                        ref.read(notificationProvider.notifier).deleteNotification(notif.id),
                    onTap: () {
                      ref.read(notificationProvider.notifier).markAsRead(notif.id);
                      context.push('/notifications/${notif.id}');
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final dynamic notif;
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notif,
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = notif.isRead
        ? AppColors.getBorder(context)
        : (isDark ? AppColors.darkPrimary.withValues(alpha: 0.5) : AppColors.primarySubtle);

    final cardBg = notif.isRead
        ? AppColors.getSurface(context)
        : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle);

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.crimson.withAlpha(220),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              'Delete',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
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
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!notif.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.getTextMuted(context),
                ),
                tooltip: 'Delete',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
