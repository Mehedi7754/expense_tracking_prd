import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationNotifier extends Notifier<List<NotificationModel>> {
  @override
  List<NotificationModel> build() {
    // Default clean empty state on startup (no hardcoded demo notifications)
    return const [];
  }

  Future<void> fetchNotifications() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final list = await repo.getNotifications();
      state = list;
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  void setNotifications(List<NotificationModel> notifications) {
    state = notifications;
  }

  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(id);
    } catch (_) {
      // Offline fallback
    }
  }

  void markAllAsRead() {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
  }

  void addNotification({
    required String userId,
    required String title,
    required String message,
    required String fullExplanation,
    required NotificationType type,
    String? relatedExpenseId,
    String? relatedProjectId,
  }) {
    final newNotif = NotificationModel(
      id: 'notif_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      title: title,
      message: message,
      fullExplanation: fullExplanation,
      type: type,
      relatedExpenseId: relatedExpenseId,
      relatedProjectId: relatedProjectId,
      isRead: false,
      timestamp: DateTime.now(),
    );
    state = [newNotif, ...state];
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationModel>>(NotificationNotifier.new);
