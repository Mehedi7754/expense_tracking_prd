import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository(this._client);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _client.get(ApiEndpoints.notifications);

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.patch(ApiEndpoints.markNotificationRead(notificationId));
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.delete(ApiEndpoints.deleteNotification(notificationId));
  }

  Future<void> deleteAllNotifications() async {
    await _client.delete(ApiEndpoints.deleteAllNotifications);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});
