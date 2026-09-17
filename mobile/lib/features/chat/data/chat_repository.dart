import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatMessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final String status;
  final DateTime createdAt;
  final bool isBlocked;

  ChatMessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.createdAt,
    this.isBlocked = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      matchId: json['match_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['encrypted_text'] as String? ?? json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }
}

class ChatRepository {
  final Dio _client;
  WebSocketChannel? _channel;
  final StreamController<ChatMessageModel> _messageController =
      StreamController<ChatMessageModel>.broadcast();
  final StreamController<String> _antiLeakAlertController =
      StreamController<String>.broadcast();

  Stream<ChatMessageModel> get messageStream => _messageController.stream;
  Stream<String> get antiLeakAlertStream => _antiLeakAlertController.stream;

  ChatRepository({Dio? client})
      : _client = client ?? createApiClient(baseUrl: EnvConfig.apiBaseUrl);

  /// Connect to WebSocket chat gateway
  Future<void> connect() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final wsUri = Uri.parse('${EnvConfig.wsBaseUrl}/ws/chat?token=$token');

      _channel = WebSocketChannel.connect(wsUri);
      _channel?.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
            final event = jsonMap['event'] as String?;

            if (event == 'anti_leak_violation') {
              final reason = jsonMap['message'] as String? ??
                  'Sharing personal contact details is prohibited.';
              _antiLeakAlertController.add(reason);
            } else if (event == 'incoming_message') {
              _messageController.add(ChatMessageModel.fromJson(jsonMap));
            } else if (event == 'message_sent') {
              debugPrint('Message sent acknowledged: ${jsonMap['msg_id']}');
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (err) {
          debugPrint('Chat WebSocket error: $err');
        },
        onDone: () {
          debugPrint('Chat WebSocket disconnected');
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to Chat WebSocket: $e');
    }
  }

  /// Send message over WebSocket
  void sendMessage({
    required String matchId,
    required String recipientId,
    required String content,
  }) {
    if (_channel == null) {
      debugPrint('WebSocket not connected');
      return;
    }

    final payload = jsonEncode({
      'type': 'message',
      'match_id': matchId,
      'recipient_id': recipientId,
      'content': content,
    });

    _channel?.sink.add(payload);
  }

  /// Fetch message history from REST API
  Future<List<ChatMessageModel>> getHistory(String matchId, {int limit = 50}) async {
    try {
      final response = await _client.get(
        '/api/v1/chat/history/$matchId',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      return [];
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
    _antiLeakAlertController.close();
  }
}
