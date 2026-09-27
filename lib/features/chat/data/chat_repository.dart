import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_models.dart';
import 'chat_seed_data.dart';
import 'chat_websocket_service.dart';

/// Riverpod Providers for Chat Data Layer
final chatWebSocketServiceProvider = Provider<ChatWebSocketService>((ref) {
  final service = ChatWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final ws = ref.watch(chatWebSocketServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(ws, apiClient);
});

final conversationsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getConversations();
});

final recentSparksProvider = FutureProvider<List<SparkProfile>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getRecentSparks();
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, matchId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMessagesForMatch(matchId);
});

/// Repository orchestrating active conversations, recent sparks, and message delivery
class ChatRepository {
  final ChatWebSocketService _wsService;
  final ApiClient? _apiClient;
  final _uuid = const Uuid();

  final List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesByMatch = {};
  final List<SparkProfile> _sparks = [];

  ChatRepository(this._wsService, [this._apiClient]) {
    _initializeSeedData();
    _subscribeToWebSocketEvents();
  }

  void _initializeSeedData() {
    _sparks.addAll(ChatSeedData.getInitialSparks());
    _conversations.addAll(ChatSeedData.getInitialConversations());
    _messagesByMatch.addAll(ChatSeedData.getInitialMessages());
  }

  void _subscribeToWebSocketEvents() {
    _wsService.eventStream.listen((event) {
      final action = event['action'];
      if (action == 'status_update') {
        final matchId = event['match_id'] as String?;
        final msgId = event['message_id'] as String?;
        final statusStr = event['status'] as String?;
        if (matchId != null && msgId != null && statusStr != null) {
          _updateMessageStatusLocally(matchId, msgId, statusStr);
        }
      }
    });
  }

  void _updateMessageStatusLocally(String matchId, String msgId, String statusStr) {
    final list = _messagesByMatch[matchId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        final newStatus = statusStr == 'read'
            ? MessageDeliveryStatus.read
            : statusStr == 'delivered'
                ? MessageDeliveryStatus.delivered
                : MessageDeliveryStatus.sent;
        list[idx] = list[idx].copyWith(status: newStatus);
      }
    }
  }

  Future<List<ChatConversation>> getConversations() async =>
      List.unmodifiable(_conversations);

  Future<List<SparkProfile>> getRecentSparks() async =>
      List.unmodifiable(_sparks);

  Future<List<ChatMessage>> getMessagesForMatch(String matchId) async {
    final msgs = _messagesByMatch[matchId] ?? [];
    return List.unmodifiable(msgs);
  }

  /// REST fallback: GET /api/v1/chat/threads
  Future<void> fetchRemoteThreadsFallback() async {
    try {
      await _apiClient?.dio.get<dynamic>('/api/v1/chat/threads');
    } catch (_) {
      // Fallback silently degrades gracefully in offline mode
    }
  }

  /// REST fallback: GET /api/v1/chat/messages/{match_id}
  Future<void> fetchRemoteMessagesFallback(String matchId) async {
    try {
      await _apiClient?.dio.get<dynamic>('/api/v1/chat/messages/$matchId');
    } catch (_) {
      // Fallback silently degrades gracefully in offline mode
    }
  }

  Future<ChatMessage> sendMessage({
    required String matchId,
    required String text,
    required String recipientId,
  }) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      matchId: matchId,
      senderId: 'me',
      recipientId: recipientId,
      text: text,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      isMe: true,
    );

    final currentList = _messagesByMatch.putIfAbsent(matchId, () => []);
    currentList.add(message);

    // Update conversation last message preview
    final convIdx = _conversations.indexWhere((c) => c.matchId == matchId);
    if (convIdx != -1) {
      _conversations[convIdx] = _conversations[convIdx].copyWith(
        lastMessageText: text,
        lastMessageTimestamp: message.createdAt,
        lastMessageStatus: MessageDeliveryStatus.sent,
      );
    }

    // Transmit over WebSocket wire protocol
    _wsService.sendJson({
      'action': 'send_message',
      'match_id': matchId,
      'recipient_id': recipientId,
      'text': text,
      'message_id': message.id,
      'timestamp': message.createdAt.toIso8601String(),
    });

    return message;
  }

  Future<void> markMessagesAsRead(String matchId) async {
    final list = _messagesByMatch[matchId];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        if (!list[i].isMe && list[i].status != MessageDeliveryStatus.read) {
          list[i] = list[i].copyWith(status: MessageDeliveryStatus.read);
          _wsService.sendJson({
            'action': 'ack_read',
            'match_id': matchId,
            'message_id': list[i].id,
            'sender_id': list[i].senderId,
          });
        }
      }
    }
    final convIdx = _conversations.indexWhere((c) => c.matchId == matchId);
    if (convIdx != -1) {
      _conversations[convIdx] = _conversations[convIdx].copyWith(unreadCount: 0);
    }
  }
}
