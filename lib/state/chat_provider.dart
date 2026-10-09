import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import 'auth_provider.dart';

// Total unread messages count across all conversations
class ChatUnreadCountNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    refresh();
    return 0;
  }

  Future<void> refresh() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final count = await repo.getUnreadCount();
      state = count;
    } catch (_) {}
  }

  void decrementBy(int amount) {
    state = (state - amount).clamp(0, 9999);
  }
}

final chatUnreadCountProvider = NotifierProvider<ChatUnreadCountNotifier, int>(
  ChatUnreadCountNotifier.new,
);

// Conversation Channels Provider — instant load from cache, refresh in background
class ChatChannelsNotifier extends Notifier<AsyncValue<List<ChatChannelModel>>> {
  Timer? _pollTimer;
  static List<ChatChannelModel>? _cache;

  @override
  AsyncValue<List<ChatChannelModel>> build() {
    ref.keepAlive();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => fetchChannels(silent: true));
    ref.onDispose(() => _pollTimer?.cancel());

    // Schedule instant background sync
    Future.microtask(() => fetchChannels(silent: true));

    // Instant return of cached or empty list — NEVER blocks UI with loading spinner
    return AsyncValue.data(_cache ?? const []);
  }

  Future<void> fetchChannels({bool silent = true}) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final channels = await repo.getChannels();
      _cache = channels;
      state = AsyncValue.data(channels);
    } catch (e, st) {
      if (!silent) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void markChannelReadLocally(String channelId) {
    state.whenData((channels) {
      final updated = channels.map((c) {
        if (c.id == channelId) {
          return c.copyWith(unreadCount: 0);
        }
        return c;
      }).toList();
      _cache = updated;
      state = AsyncValue.data(updated);
    });
  }
}

final chatChannelsProvider =
    NotifierProvider<ChatChannelsNotifier, AsyncValue<List<ChatChannelModel>>>(
  ChatChannelsNotifier.new,
);

// Active Message Thread Provider (per channel)
class ChatMessageNotifier extends Notifier<AsyncValue<List<ChatMessageModel>>> {
  final String channelId;
  Timer? _threadPollTimer;
  StreamSubscription? _sseSub;
  static final Map<String, List<ChatMessageModel>> _cache = {};

  ChatMessageNotifier(this.channelId);

  @override
  AsyncValue<List<ChatMessageModel>> build() {
    ref.keepAlive();
    _threadPollTimer?.cancel();
    _sseSub?.cancel();

    _threadPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => fetchMessages(silent: true));
    ref.onDispose(() {
      _threadPollTimer?.cancel();
      _sseSub?.cancel();
    });

    _initRealTimeStream();

    // Schedule instant background sync
    Future.microtask(() => fetchMessages(silent: true));

    // Instant return of cached messages — ZERO waiting or spinner!
    return AsyncValue.data(_cache[channelId] ?? const []);
  }

  void _initRealTimeStream() {
    try {
      final client = ref.read(apiClientProvider);
      final baseUrl = client.effectiveBaseUrl;
      final token = client.authToken;
      final uri = Uri.parse('$baseUrl/chat/channels/$channelId/stream');

      final request = http.Request('GET', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';

      final httpClient = http.Client();
      httpClient.send(request).then((res) {
        _sseSub = res.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.startsWith('data:')) {
            final jsonStr = line.substring(5).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final json = jsonDecode(jsonStr);
                final auth = ref.read(authProvider);
                final incoming = ChatMessageModel.fromJson(
                  Map<String, dynamic>.from(json),
                  currentUserId: auth.currentUser?.id,
                );
                _handleRealTimeMessage(incoming);
              } catch (_) {}
            }
          }
        }, onError: (_) {});
      }).catchError((_) {});
    } catch (_) {}
  }

  void _handleRealTimeMessage(ChatMessageModel incoming) {
    state.whenData((current) {
      if (!current.any((m) => m.id == incoming.id)) {
        state = AsyncValue.data([...current, incoming]);
        ref.read(chatChannelsProvider.notifier).fetchChannels(silent: true);
      }
    });
  }

  Future<void> fetchMessages({bool silent = true}) async {
    if (!silent && state is! AsyncData) {
      state = const AsyncValue.loading();
    }
    try {
      final repo = ref.read(chatRepositoryProvider);
      final auth = ref.read(authProvider);
      final msgs = await repo.getMessages(channelId, currentUserId: auth.currentUser?.id);
      _cache[channelId] = msgs;
      state = AsyncValue.data(msgs);

      // Mark channel as read on backend and locally
      unawaited(repo.markChannelAsRead(channelId));
      ref.read(chatChannelsProvider.notifier).markChannelReadLocally(channelId);
      ref.read(chatUnreadCountProvider.notifier).refresh();
    } catch (e, st) {
      if (!silent) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> sendMessage({
    required String content,
    String? imageUrl,
    String? projectId,
    String? projectName,
    String? projectCode,
  }) async {
    final auth = ref.read(authProvider);
    final currentUserId = auth.currentUser?.id;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessageModel(
      id: tempId,
      channelId: channelId,
      senderId: currentUserId ?? '',
      senderName: 'You',
      content: content,
      imageUrl: imageUrl,
      projectId: projectId,
      projectName: projectName,
      projectCode: projectCode,
      createdAt: DateTime.now(),
      isMe: true,
    );

    // Immediate optimistic append to local UI
    state.whenData((current) {
      state = AsyncValue.data([...current, optimisticMsg]);
    });

    try {
      final repo = ref.read(chatRepositoryProvider);
      final sent = await repo.sendMessage(
        channelId: channelId,
        content: content,
        imageUrl: imageUrl,
        projectId: projectId,
        currentUserId: currentUserId,
      );

      if (sent != null) {
        state.whenData((current) {
          final updated = current.map((m) => m.id == tempId ? sent : m).toList();
          state = AsyncValue.data(updated);
        });
        ref.read(chatChannelsProvider.notifier).fetchChannels(silent: true);
        return true;
      }
      return true;
    } catch (e) {
      // Revert optimistic update on error
      state.whenData((current) {
        state = AsyncValue.data(current.where((m) => m.id != tempId).toList());
      });
      return false;
    }
  }
}

final chatMessagesProvider =
    NotifierProvider.family<ChatMessageNotifier, AsyncValue<List<ChatMessageModel>>, String>(
  (channelId) => ChatMessageNotifier(channelId),
);
