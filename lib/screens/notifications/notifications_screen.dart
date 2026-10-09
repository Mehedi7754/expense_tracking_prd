import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/notification_router.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/notification_provider.dart';
import '../../state/user_management_provider.dart';

enum NotificationCategoryFilter {
  all,
  unread,
  expenses,
  projects,
  attendance,
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategoryFilter _selectedFilter = NotificationCategoryFilter.all;

  bool _matchesFilter(NotificationModel notif, NotificationCategoryFilter filter) {
    switch (filter) {
      case NotificationCategoryFilter.all:
        return true;
      case NotificationCategoryFilter.unread:
        return !notif.isRead;
      case NotificationCategoryFilter.expenses:
        return notif.type == NotificationType.expenseApproved ||
            notif.type == NotificationType.expenseRejected ||
            notif.type == NotificationType.expenseSubmitted ||
            notif.type == NotificationType.justificationSubmitted ||
            notif.type == NotificationType.justificationApproved ||
            notif.type == NotificationType.justificationRejected ||
            notif.type == NotificationType.salaryReady ||
            notif.type == NotificationType.payrollFinalized ||
            notif.type == NotificationType.revenueReceived;
      case NotificationCategoryFilter.projects:
        return notif.type == NotificationType.projectAssigned ||
            notif.type == NotificationType.budgetWarning ||
            notif.type == NotificationType.budgetCritical ||
            notif.type == NotificationType.commentAdded ||
            notif.type == NotificationType.memberAdded;
      case NotificationCategoryFilter.attendance:
        return notif.type == NotificationType.attendanceReminder ||
            notif.type == NotificationType.attendanceLate ||
            notif.type == NotificationType.absenceDeducted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final user = ref.watch(authProvider).currentUser;
    final allUsers = ref.watch(userManagementProvider);
    final isDark = AppColors.isDark(context);

    // Filter notifications: Super Admin and Finance see all alerts; others see their own or broadcast
    final userNotifs = notifications.where((n) {
      if (user == null) return true;
      if (user.role == UserRole.mainAdmin || user.role == UserRole.finance) {
        return true;
      }
      return n.userId == user.id || n.userId.isEmpty;
    }).toList();

    // Ensure notifications are strictly sorted newest first
    userNotifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final unreadCount = userNotifs.where((n) => !n.isRead).length;
    final hasUnread = unreadCount > 0;

    // Filter by selected category pill
    final filteredNotifs = userNotifs.where((n) => _matchesFilter(n, _selectedFilter)).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
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
          if (userNotifs.isNotEmpty)
            IconButton(
              tooltip: 'Delete All',
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: isDark ? AppColors.crimsonAccent : AppColors.crimson,
                size: 22,
              ),
              onPressed: () {
                ref.read(notificationProvider.notifier).deleteAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications permanently deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
          : Column(
              children: [
                // Top Action & Category Filter Bar
                Container(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Column(
                    children: [
                      // Status and Mark-All-Read Strip
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: hasUnread
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      hasUnread
                                          ? '$unreadCount unread ${unreadCount == 1 ? "notification" : "notifications"}'
                                          : 'All notifications caught up',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasUnread)
                              InkWell(
                                onTap: () {
                                  ref.read(notificationProvider.notifier).markAllAsRead();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('All notifications marked as read'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 16,
                                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mark all read',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Filter Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterPill(
                              label: 'All',
                              icon: Icons.all_inbox_rounded,
                              filter: NotificationCategoryFilter.all,
                              count: userNotifs.length,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Unread',
                              icon: Icons.mark_email_unread_rounded,
                              filter: NotificationCategoryFilter.unread,
                              count: unreadCount,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Expenses',
                              icon: Icons.receipt_long_rounded,
                              filter: NotificationCategoryFilter.expenses,
                              count: userNotifs.where((n) => _matchesFilter(n, NotificationCategoryFilter.expenses)).length,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Projects',
                              icon: Icons.folder_open_rounded,
                              filter: NotificationCategoryFilter.projects,
                              count: userNotifs.where((n) => _matchesFilter(n, NotificationCategoryFilter.projects)).length,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Attendance',
                              icon: Icons.schedule_rounded,
                              filter: NotificationCategoryFilter.attendance,
                              count: userNotifs.where((n) => _matchesFilter(n, NotificationCategoryFilter.attendance)).length,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification List
                Expanded(
                  child: filteredNotifs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.filter_list_off_rounded,
                                    size: 30,
                                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${_filterName(_selectedFilter)} notifications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try selecting a different filter above to view all notifications.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _selectedFilter = NotificationCategoryFilter.all),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Show All Notifications'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filteredNotifs.length,
                            itemBuilder: (ctx, i) {
                              final notif = filteredNotifs[i];
                              return _NotificationCard(
                                notif: notif,
                                allUsers: allUsers,
                                isDark: isDark,
                                onDelete: () => ref
                                    .read(notificationProvider.notifier)
                                    .deleteNotification(notif.id),
                                onTap: () {
                                  ref.read(notificationProvider.notifier).markAsRead(notif.id);
                                  context.push(NotificationRouter.resolve({
                                    'type': notif.type.name,
                                    'expenseId': notif.relatedExpenseId,
                                    'projectId': notif.relatedProjectId,
                                    'notificationId': notif.id,
                                  }));
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required IconData icon,
    required NotificationCategoryFilter filter,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;
    final activeBg = isDark ? const Color(0xFF4338CA) : const Color(0xFF4F46E5);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final activeText = Colors.white;
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF6366F1) : const Color(0xFF4338CA))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeText : inactiveText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? activeText : inactiveText,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _filterName(NotificationCategoryFilter filter) {
    switch (filter) {
      case NotificationCategoryFilter.all:
        return 'all';
      case NotificationCategoryFilter.unread:
        return 'unread';
      case NotificationCategoryFilter.expenses:
        return 'expense';
      case NotificationCategoryFilter.projects:
        return 'project';
      case NotificationCategoryFilter.attendance:
        return 'attendance';
    }
  }
}

class _CategoryStyle {
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;

  const _CategoryStyle({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
  });
}

_CategoryStyle _getCategoryStyle(NotificationType type, bool isDark) {
  if (type == NotificationType.expenseApproved ||
      type == NotificationType.expenseRejected ||
      type == NotificationType.expenseSubmitted ||
      type == NotificationType.justificationSubmitted ||
      type == NotificationType.justificationApproved ||
      type == NotificationType.justificationRejected ||
      type == NotificationType.salaryReady ||
      type == NotificationType.payrollFinalized ||
      type == NotificationType.revenueReceived) {
    return _CategoryStyle(
      label: 'EXPENSE',
      icon: Icons.receipt_long_rounded,
      primaryColor: const Color(0xFFD97706),
      backgroundColor: isDark ? const Color(0xFF451A03).withValues(alpha: 0.6) : const Color(0xFFFEF3C7),
    );
  }
  if (type == NotificationType.projectAssigned ||
      type == NotificationType.budgetWarning ||
      type == NotificationType.budgetCritical ||
      type == NotificationType.commentAdded ||
      type == NotificationType.memberAdded) {
    return _CategoryStyle(
      label: 'PROJECT',
      icon: Icons.folder_open_rounded,
      primaryColor: const Color(0xFF4F46E5),
      backgroundColor: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.6) : const Color(0xFFEEF2FF),
    );
  }
  if (type == NotificationType.attendanceReminder ||
      type == NotificationType.attendanceLate ||
      type == NotificationType.absenceDeducted) {
    return _CategoryStyle(
      label: 'ATTENDANCE',
      icon: Icons.schedule_rounded,
      primaryColor: const Color(0xFF059669),
      backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFD1FAE5),
    );
  }
  return _CategoryStyle(
    label: 'SYSTEM',
    icon: Icons.notifications_active_rounded,
    primaryColor: const Color(0xFF7C3AED),
    backgroundColor: isDark ? const Color(0xFF2E1065).withValues(alpha: 0.6) : const Color(0xFFF3E8FF),
  );
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notif;
  final List<UserModel> allUsers;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notif,
    required this.allUsers,
    required this.isDark,
    required this.onDelete,
    required this.onTap,
  });

  UserModel? _findSenderUser() {
    // 1. If actorId is explicitly present in notification, find direct match
    if (notif.actorId != null && notif.actorId!.isNotEmpty) {
      final match = allUsers.where((u) => u.id == notif.actorId);
      if (match.isNotEmpty) return match.first;
    }

    // 2. Search message and title for any team member's email or name
    final lowerMsg = notif.message.toLowerCase();
    final lowerTitle = notif.title.toLowerCase();

    for (final u in allUsers) {
      if (u.email.isNotEmpty && (lowerMsg.contains(u.email.toLowerCase()) || lowerTitle.contains(u.email.toLowerCase()))) {
        return u;
      }
    }
    for (final u in allUsers) {
      if (u.name.trim().isNotEmpty && (lowerMsg.contains(u.name.toLowerCase()) || lowerTitle.contains(u.name.toLowerCase()))) {
        return u;
      }
    }

    // 3. Fallback: only if it's a personal notification (or no specific actor matched)
    if (notif.userId.isNotEmpty) {
      final match = allUsers.where((u) => u.id == notif.userId);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final senderUser = _findSenderUser();

    // Resolve avatar URL: prioritize explicit actorAvatarUrl, then matched senderUser avatar
    final avatarUrl = (notif.actorAvatarUrl != null && notif.actorAvatarUrl!.isNotEmpty)
        ? notif.actorAvatarUrl
        : senderUser?.avatarUrl;

    // Resolve display name for avatar initials
    final displayName = (notif.actorName != null && notif.actorName!.trim().isNotEmpty)
        ? notif.actorName!.trim()
        : (senderUser != null && senderUser.name.trim().isNotEmpty
            ? senderUser.name.trim()
            : notif.title);

    final categoryStyle = _getCategoryStyle(notif.type, isDark);

    final borderColor = notif.isRead
        ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
        : (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.6) : const Color(0xFF818CF8).withValues(alpha: 0.5));

    final cardBg = notif.isRead
        ? AppColors.getSurface(context)
        : (isDark ? const Color(0xFF161F33) : const Color(0xFFF8FAFC));

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.crimson.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: notif.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppAvatar showing the profile of the person who submitted/acted
                  AppAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    size: 44,
                    badge: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: categoryStyle.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF161F33) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          categoryStyle.icon,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content: Category Pill + Title + Message + Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryStyle.backgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryStyle.label,
                                style: TextStyle(
                                  color: categoryStyle.primaryColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormatter.formatRelative(notif.timestamp),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.getTextMuted(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppColors.getTextPrimary(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notif.message,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: notif.isRead
                                ? AppColors.getTextMuted(context)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Right status & dismiss button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(bottom: 6, top: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
