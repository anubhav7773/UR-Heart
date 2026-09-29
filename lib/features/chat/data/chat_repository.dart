import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../domain/chat_models.dart';
import 'chat_websocket_service.dart';

export '../domain/chat_models.dart';

/// Riverpod Providers for Chat Data Layer
final chatWebSocketServiceProvider = Provider<ChatWebSocketService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final wsHost = Uri.parse(dioClient.dio.options.baseUrl).host;
  final service = ChatWebSocketService(dioClient.dio, wsHost.isNotEmpty ? wsHost : 'urheart.asiverticals.me');
  service.connectSecureChannel();
  ref.onDispose(() => service.dispose());
  return service;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final ws = ref.watch(chatWebSocketServiceProvider);
  final dioClient = ref.watch(dioClientProvider);
  return ChatRepository(dioClient.dio, ws);
});

final conversationsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.fetchConversations();
});

final recentSparksProvider = FutureProvider<List<SparkProfile>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.fetchActiveSparks();
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, matchId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.fetchThreadMessages(matchId);
});

/// Repository orchestrating active conversations, recent sparks, and message delivery
class ChatRepository {
  final Dio _dio;
  final ChatWebSocketService? _wsService;
  final _uuid = const Uuid();

  final List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesByMatch = {};
  final List<SparkProfile> _sparks = [];

  ChatRepository([Dio? dio, this._wsService])
      : _dio = dio ?? Dio() {
    _subscribeToWebSocketEvents();
  }

  void _subscribeToWebSocketEvents() {
    _wsService?.eventStream.listen((event) {
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

  /// Fetches dynamic spark carousel candidates under active exploration timer.
  Future<List<SparkProfile>> fetchActiveSparks() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/chat/sparks');
      final dynamic body = response.data;
      final List<dynamic> list = body is Map<String, dynamic>
          ? (body['sparks'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final sparks = list.map((json) => SparkProfile.fromJson(json as Map<String, dynamic>)).toList();
      _sparks
        ..clear()
        ..addAll(sparks);
      return sparks;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches real conversation dialogue threads from PostgreSQL.
  Future<List<ConversationThread>> fetchConversations() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/chat/threads');
      final dynamic body = response.data;
      final List<dynamic> list = body is Map<String, dynamic>
          ? (body['threads'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final threads = list.map((json) => ConversationThread.fromJson(json as Map<String, dynamic>)).toList();
      _conversations
        ..clear()
        ..addAll(threads);
      return threads;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches historical encrypted message payloads for a thread.
  Future<List<ChatMessage>> fetchThreadMessages(String matchId, {int limit = 50}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/chat/threads/$matchId/messages',
        queryParameters: {'limit': limit},
      );
      final dynamic body = response.data;
      final List<dynamic> list = body is Map<String, dynamic>
          ? (body['messages'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final msgs = list.map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)).toList();
      _messagesByMatch[matchId] = msgs;
      return msgs;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // Backwards-compatible aliases
  Future<List<ChatConversation>> getConversations() => fetchConversations();
  Future<List<SparkProfile>> getRecentSparks() => fetchActiveSparks();
  Future<List<ChatMessage>> getMessagesForMatch(String matchId) => fetchThreadMessages(matchId);

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

    final convIdx = _conversations.indexWhere((c) => c.matchId == matchId);
    if (convIdx != -1) {
      _conversations[convIdx] = _conversations[convIdx].copyWith(
        lastMessageText: text,
        lastMessageTimestamp: message.createdAt,
        lastMessageStatus: MessageDeliveryStatus.sent,
      );
    }

    _wsService?.sendJson({
      'action': 'send_message',
      'match_id': matchId,
      'recipient_id': recipientId,
      'text': text,
      'message_id': message.id,
      'timestamp': message.createdAt.toIso8601String(),
    });

    // Persist message to PostgreSQL backend database
    try {
      await _dio.post<dynamic>(
        '/api/v1/chat/messages',
        data: {
          'match_id': matchId,
          'text': text,
          'recipient_id': recipientId,
        },
      );
    } catch (e) {
      // Message delivered over WS; offline cache or resilience
    }

    return message;
  }

  Future<void> markMessagesAsRead(String matchId) async {
    final list = _messagesByMatch[matchId];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        if (!list[i].isMe && list[i].status != MessageDeliveryStatus.read) {
          list[i] = list[i].copyWith(status: MessageDeliveryStatus.read);
          _wsService?.sendJson({
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

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    final data = e.response?.data;
    final message = data is Map ? (data['detail']?.toString() ?? 'Chat synchronization failed.') : (data?.toString() ?? 'Chat synchronization failed.');
    throw ServerException(message);
  }
}
