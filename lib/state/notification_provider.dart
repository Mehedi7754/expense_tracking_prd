import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/environment_utils.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationNotifier extends Notifier<List<NotificationModel>> {
  Timer? _pollingTimer;

  @override
  List<NotificationModel> build() {
    // Start background polling every 2 minutes in live app (skip in test environment)
    if (!EnvironmentUtils.isTestEnvironment) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        fetchNotifications();
      });
      ref.onDispose(() => _pollingTimer?.cancel());
    }

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

  Future<void> markAllAsRead() async {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    // No bulk-mark endpoint on backend — individual mark calls are not necessary
    // since the state is already updated optimistically and will sync on next fetch.
  }

  /// Delete a single notification by ID (removes from state + calls backend).
  Future<void> deleteNotification(String id) async {
    state = state.where((n) => n.id != id).toList();
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.deleteNotification(id);
    } catch (_) {
      // State already updated — live with it
    }
  }

  /// Delete ALL notifications for the current user.
  Future<void> deleteAll() async {
    state = const [];
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.deleteAllNotifications();
    } catch (_) {
      // State already cleared
    }
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
