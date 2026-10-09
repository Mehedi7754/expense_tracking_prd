import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/chat_models.dart';
import 'package:expense_tracking_prd/core/routing/route_paths.dart';
import 'package:expense_tracking_prd/core/services/notification_router.dart';

void main() {
  group('Chat Models & Serialization Tests', () {
    test('ChatChannelModel fromJson and toJson roundtrip (direct)', () {
      final json = {
        'id': 'chan-123',
        'type': 'direct',
        'name': null,
        'project_id': null,
        'unread_count': '2',
        'updated_at': '2026-10-09T12:00:00.000Z',
        'other_user': {
          'id': 'user-2',
          'full_name': 'Jane Doe',
          'email': 'jane@example.com',
          'role': 'projectMember',
          'avatar_url': 'https://example.com/avatar.png',
        },
        'last_message': {
          'id': 'msg-1',
          'channel_id': 'chan-123',
          'sender_id': 'user-2',
          'sender_name': 'Jane Doe',
          'content': 'Hello team!',
          'created_at': '2026-10-09T12:00:00.000Z',
        },
      };

      final channel = ChatChannelModel.fromJson(json);
      expect(channel.id, 'chan-123');
      expect(channel.type, 'direct');
      expect(channel.unreadCount, 2);
      expect(channel.title, 'Jane Doe');
      expect(channel.otherUser?.fullName, 'Jane Doe');
      expect(channel.lastMessage?.content, 'Hello team!');
      expect(channel.subtitle, 'Hello team!');
    });

    test('ChatChannelModel fromJson and toJson roundtrip (project room)', () {
      final json = {
        'id': 'chan-456',
        'type': 'project',
        'name': 'Project Alpha Chat',
        'project_id': 'proj-1',
        'project_name': 'Project Alpha',
        'project_code': 'PRJ-2026-001',
        'project_status': 'inProgress',
        'unread_count': 0,
        'updated_at': '2026-10-09T12:05:00.000Z',
      };

      final channel = ChatChannelModel.fromJson(json);
      expect(channel.id, 'chan-456');
      expect(channel.type, 'project');
      expect(channel.title, 'Project Alpha');
      expect(channel.projectCode, 'PRJ-2026-001');
      expect(channel.unreadCount, 0);
      expect(channel.subtitle, 'Project group discussion');
    });

    test('ChatChannelModel photo subtitle preview', () {
      final json = {
        'id': 'chan-789',
        'type': 'direct',
        'unread_count': 1,
        'updated_at': '2026-10-09T12:00:00.000Z',
        'last_message': {
          'id': 'msg-2',
          'channel_id': 'chan-789',
          'sender_id': 'user-3',
          'sender_name': 'Mark',
          'content': 'Site layout blueprint',
          'image_url': 'https://example.com/site.png',
          'created_at': '2026-10-09T12:00:00.000Z',
        },
      };

      final channel = ChatChannelModel.fromJson(json);
      expect(channel.subtitle, '📷 Site layout blueprint');
    });

    test('ChatMessageModel with project mention and photo attachment', () {
      final json = {
        'id': 'msg-99',
        'channel_id': 'chan-123',
        'sender_id': 'me-1',
        'sender_name': 'Alex',
        'content': 'Check this site photo for #PRJ-2026-001',
        'image_url': 'data:image/jpeg;base64,abc123xyz',
        'project_id': 'proj-1',
        'project_name': 'Metro Rail Bridge',
        'project_code': 'PRJ-2026-001',
        'created_at': '2026-10-09T12:10:00.000Z',
        'is_me': true,
      };

      final message = ChatMessageModel.fromJson(json, currentUserId: 'me-1');
      expect(message.id, 'msg-99');
      expect(message.isMe, true);
      expect(message.imageUrl, 'data:image/jpeg;base64,abc123xyz');
      expect(message.projectId, 'proj-1');
      expect(message.projectName, 'Metro Rail Bridge');
      expect(message.projectCode, 'PRJ-2026-001');
      expect(message.hasImage, true);
      expect(message.hasProject, true);
    });

    test('ChatMessageModel without mentions or attachments', () {
      final json = {
        'id': 'msg-100',
        'channel_id': 'chan-123',
        'sender_id': 'other-1',
        'sender_name': 'John',
        'content': 'Simple text message',
        'created_at': '2026-10-09T12:15:00.000Z',
      };

      final message = ChatMessageModel.fromJson(json, currentUserId: 'me-1');
      expect(message.isMe, false);
      expect(message.hasImage, false);
      expect(message.hasProject, false);
    });

    test('Chat Notification routing encodes and maps to ChatThreadScreen path', () {
      // Chat notification payload must NOT route to notifications activity page
      final chatData = {
        'type': 'chat',
        'channelId': 'channel-99',
      };
      final chatPayload = NotificationRouter.encode(chatData);

      final decodedData = Uri.splitQueryString(chatPayload);
      final route = NotificationRouter.resolve(decodedData);
      expect(route, RoutePaths.chatThread('channel-99'));
      expect(route.contains('/chat/'), true);
      expect(route.contains('notifications'), false);
    });
  });
}
