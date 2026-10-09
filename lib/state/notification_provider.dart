import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/environment_utils.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../core/services/push_notification_service.dart';

const String _kCustomNotificationsKey = 'gw_custom_notifications_cache';
const String _kDeletedNotificationIdsKey = 'gw_deleted_notification_ids_v2';
const String _kDeletedNotificationHashesKey = 'gw_deleted_notification_hashes_v2';

class NotificationNotifier extends Notifier<List<NotificationModel>> {
  Timer? _pollingTimer;
  final Set<String> _deletedIds = {};
  final Set<String> _deletedContentHashes = {};

  @override
  List<NotificationModel> build() {
    _init();
    // Poll every 4 seconds so new notifications arrive near-instantly
    if (!EnvironmentUtils.isTestEnvironment) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        fetchNotifications();
      });
      ref.onDispose(() => _pollingTimer?.cancel());
    }

    return const [];
  }

  Future<void> _init() async {
    await _loadCachedNotifications();
    await fetchNotifications();
  }

  Future<Set<String>> _getDeletedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDeletedNotificationIdsKey) ?? [];
      return {..._deletedIds, ...list};
    } catch (_) {
      return _deletedIds;
    }
  }

  Future<Set<String>> _getDeletedHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDeletedNotificationHashesKey) ?? [];
      return {..._deletedContentHashes, ...list};
    } catch (_) {
      return _deletedContentHashes;
    }
  }

  Future<void> _recordDeleted({Iterable<String>? ids, Iterable<String>? hashes}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ids != null && ids.isNotEmpty) {
        _deletedIds.addAll(ids);
        final current = (prefs.getStringList(_kDeletedNotificationIdsKey) ?? []).toSet();
        current.addAll(ids);
        await prefs.setStringList(_kDeletedNotificationIdsKey, current.toList());
      }
      if (hashes != null && hashes.isNotEmpty) {
        _deletedContentHashes.addAll(hashes);
        final current = (prefs.getStringList(_kDeletedNotificationHashesKey) ?? []).toSet();
        current.addAll(hashes);
        await prefs.setStringList(_kDeletedNotificationHashesKey, current.toList());
      }
    } catch (_) {}
  }

  String _hashContent(NotificationModel n) {
    return '${n.title.trim()}|${n.message.trim()}';
  }

  bool _isDeleted(NotificationModel n, Set<String> deletedIds, Set<String> deletedHashes) {
    if (n.id.isNotEmpty && deletedIds.contains(n.id)) return true;
    final h = _hashContent(n);
    if (deletedHashes.contains(h)) return true;
    return false;
  }

  Future<void> _loadCachedNotifications() async {
    if (EnvironmentUtils.isTestEnvironment) return;
    try {
      final deletedIds = await _getDeletedIds();
      final deletedHashes = await _getDeletedHashes();
      _deletedIds.addAll(deletedIds);
      _deletedContentHashes.addAll(deletedHashes);

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kCustomNotificationsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map(NotificationModel.fromJson)
            .where((n) => !_isDeleted(n, deletedIds, deletedHashes))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = list;
      }
    } catch (_) {}
  }

  Future<void> _persistNotifications() async {
    if (EnvironmentUtils.isTestEnvironment) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((n) => n.toJson()).toList();
      await prefs.setString(_kCustomNotificationsKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final deletedIds = await _getDeletedIds();
      final deletedHashes = await _getDeletedHashes();

      final repo = ref.read(notificationRepositoryProvider);
      final remoteList = await repo.getNotifications();

      // Filter out locally deleted IDs/contents to prevent them from ever reappearing
      final filteredRemoteList = remoteList.where((n) => !_isDeleted(n, deletedIds, deletedHashes)).toList();

      // Authoritative remote list with recent optimistic additions:
      final remoteIds = filteredRemoteList.map((n) => n.id).toSet();
      final now = DateTime.now();
      final recentLocalOnly = state
          .where((n) =>
              !remoteIds.contains(n.id) &&
              now.difference(n.timestamp).inSeconds < 15 &&
              !_isDeleted(n, deletedIds, deletedHashes))
          .toList();

      final merged = [...filteredRemoteList, ...recentLocalOnly];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Trigger OS-level push notification for newly received unread notifications
      final existingIds = state.map((n) => n.id).toSet();
      for (final n in filteredRemoteList) {
        if (!n.isRead && !existingIds.contains(n.id) && now.difference(n.timestamp).inMinutes < 60) {
          final type = n.type.name.toLowerCase();
          if (type.contains('expense')) {
            PushNotificationService.instance.showExpenseAlert(
              title: n.title,
              body: n.message,
              notificationId: n.id,
              expenseId: n.relatedExpenseId,
            );
          } else if (type.contains('attendance')) {
            PushNotificationService.instance.showAttendanceReminder(
              title: n.title,
              body: n.message,
              notificationId: n.id,
            );
          } else {
            PushNotificationService.instance.showImmediate(
              title: n.title,
              body: n.message,
              notificationId: n.id,
            );
          }
        }
      }

      state = merged;
      await _persistNotifications();
    } catch (_) {
      // Keep existing state on network disconnect
    }
  }

  Future<void> clearCache() async {
    // Only clears cached notifications list, NEVER clears the permanent deleted sets!
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCustomNotificationsKey);
    } catch (_) {}
  }

  void setNotifications(List<NotificationModel> notifications) async {
    final deletedIds = await _getDeletedIds();
    final deletedHashes = await _getDeletedHashes();
    state = notifications.where((n) => !_isDeleted(n, deletedIds, deletedHashes)).toList();
    _persistNotifications();
  }

  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _persistNotifications();

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
    await _persistNotifications();
  }

  /// Delete a single notification permanently.
  Future<void> deleteNotification(String id) async {
    final notif = state.firstWhere(
      (n) => n.id == id,
      orElse: () => NotificationModel(
        id: '',
        userId: '',
        title: '',
        message: '',
        fullExplanation: '',
        type: NotificationType.general,
        timestamp: DateTime.now(),
      ),
    );

    final List<String> hashes = [];
    if (notif.id.isNotEmpty) {
      hashes.add(_hashContent(notif));
    }

    await _recordDeleted(ids: [id], hashes: hashes);

    state = state.where((n) => n.id != id).toList();
    await _persistNotifications();

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.deleteNotification(id);
    } catch (_) {}
  }

  /// Delete ALL notifications permanently.
  Future<void> deleteAll() async {
    final ids = state.map((n) => n.id).toList();
    final hashes = state.map((n) => _hashContent(n)).toList();

    await _recordDeleted(ids: ids, hashes: hashes);

    state = const [];
    await _persistNotifications();

    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.deleteAllNotifications();
    } catch (_) {}
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
    _persistNotifications();

    if (type == NotificationType.expenseApproved || type == NotificationType.expenseRejected || type == NotificationType.expenseSubmitted) {
      PushNotificationService.instance.showExpenseAlert(
        title: title,
        body: message,
        notificationId: newNotif.id,
        expenseId: relatedExpenseId,
      );
    } else if (type == NotificationType.attendanceReminder ||
        type == NotificationType.attendanceLate ||
        type == NotificationType.attendanceEarly) {
      PushNotificationService.instance.showAttendanceReminder(
        title: title,
        body: message,
        notificationId: newNotif.id,
      );
    } else {
      PushNotificationService.instance.showImmediate(
        title: title,
        body: message,
        notificationId: newNotif.id,
      );
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationModel>>(NotificationNotifier.new);
