import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ChatRepository(client);
});

class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  Future<List<ChatChannelModel>> getChannels() async {
    final response = await _client.get('/chat/channels');
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(ChatChannelModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<String> getOrCreateDirectChannel(String recipientId) async {
    final response = await _client.post(
      '/chat/channels/direct',
      body: {'recipientId': recipientId},
    );
    if (response is Map<String, dynamic>) {
      return (response['channelId'] ?? response['id'] ?? '').toString();
    }
    return '';
  }

  Future<String> getOrCreateProjectChannel(String projectId) async {
    final response = await _client.post(
      '/chat/channels/project',
      body: {'projectId': projectId},
    );
    if (response is Map<String, dynamic>) {
      return (response['channelId'] ?? response['id'] ?? '').toString();
    }
    return '';
  }

  Future<List<ChatMessageModel>> getMessages(String channelId, {int limit = 50, String? currentUserId}) async {
    final response = await _client.get('/chat/channels/$channelId/messages?limit=$limit');
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => ChatMessageModel.fromJson(json, currentUserId: currentUserId))
          .toList();
    }
    return [];
  }

  Future<ChatMessageModel?> sendMessage({
    required String channelId,
    String content = '',
    String? imageUrl,
    String? projectId,
    String? currentUserId,
  }) async {
    final response = await _client.post(
      '/chat/channels/$channelId/messages',
      body: {
        'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (projectId != null) 'projectId': projectId,
      },
    );
    if (response is Map<String, dynamic>) {
      return ChatMessageModel.fromJson(response, currentUserId: currentUserId);
    }
    return null;
  }

  Future<void> markChannelAsRead(String channelId) async {
    try {
      await _client.post('/chat/channels/$channelId/read');
    } catch (_) {}
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.get('/chat/unread-count');
      if (response is Map<String, dynamic>) {
        return int.tryParse(response['unreadCount']?.toString() ?? '0') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<String?> uploadPhoto(String base64Data) async {
    final response = await _client.post(
      '/chat/upload',
      body: {'file': base64Data},
    );
    if (response is Map<String, dynamic> && response['url'] != null) {
      return response['url'].toString();
    }
    return null;
  }
}
