import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/security/chat_crypto_service.dart';
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

  ChatMessageModel copyWith({
    String? id,
    String? matchId,
    String? senderId,
    String? content,
    String? status,
    DateTime? createdAt,
    bool? isBlocked,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, {String? matchId}) {
    final mId = json['match_id']?.toString() ?? matchId ?? '';
    final rawContent = json['encrypted_text'] as String? ?? json['content'] as String? ?? '';
    final decryptedContent = ChatCryptoService.decryptMessage(rawContent, mId);

    return ChatMessageModel(
      id: json['id']?.toString() ?? json['msg_id']?.toString() ?? UniqueKey().toString(),
      matchId: mId,
      senderId: json['sender_id']?.toString() ?? '',
      content: decryptedContent,
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
  final StreamController<Map<String, dynamic>> _statusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _typingController =
      StreamController<bool>.broadcast();

  Stream<ChatMessageModel> get messageStream => _messageController.stream;
  Stream<String> get antiLeakAlertStream => _antiLeakAlertController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<bool> get typingStream => _typingController.stream;

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
              final msg = ChatMessageModel.fromJson(jsonMap);
              _messageController.add(msg);
            } else if (event == 'message_sent') {
              _statusController.add({
                'type': 'message_sent',
                'msg_id': jsonMap['msg_id'],
                'match_id': jsonMap['match_id'],
                'status': jsonMap['status'] ?? 'sent',
              });
            } else if (event == 'message_delivered') {
              _statusController.add({
                'type': 'delivered',
                'msg_id': jsonMap['msg_id'],
                'match_id': jsonMap['match_id'],
              });
            } else if (event == 'messages_read') {
              _statusController.add({
                'type': 'read',
                'match_id': jsonMap['match_id'],
                'reader_id': jsonMap['reader_id'],
              });
            } else if (event == 'user_typing') {
              _typingController.add(jsonMap['is_typing'] as bool? ?? false);
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

  /// Send message over WebSocket with client-side E2EE encryption
  void sendMessage({
    required String matchId,
    required String recipientId,
    required String content,
  }) {
    if (_channel == null) {
      debugPrint('WebSocket not connected');
      return;
    }

    final encryptedContent = ChatCryptoService.encryptMessage(content, matchId);

    final payload = jsonEncode({
      'type': 'message',
      'match_id': matchId,
      'recipient_id': recipientId,
      'content': encryptedContent,
    });

    _channel?.sink.add(payload);
  }

  /// Sends delivery acknowledgement (sent -> delivered)
  void sendDeliveryAck({
    required String matchId,
    required dynamic msgId,
    required String recipientId,
  }) {
    if (_channel == null) return;
    _channel?.sink.add(jsonEncode({
      'type': 'delivery_ack',
      'match_id': matchId,
      'msg_id': msgId,
      'recipient_id': recipientId,
    }));
  }

  /// Sends read receipt (delivered -> read: double blue ticks)
  void sendReadReceipt({
    required String matchId,
    required String recipientId,
  }) {
    if (_channel == null) return;
    _channel?.sink.add(jsonEncode({
      'type': 'read_receipt',
      'match_id': matchId,
      'recipient_id': recipientId,
    }));
  }

  /// Emits typing status
  void sendTyping({
    required String matchId,
    required String recipientId,
    required bool isTyping,
  }) {
    if (_channel == null) return;
    _channel?.sink.add(jsonEncode({
      'type': 'typing',
      'match_id': matchId,
      'recipient_id': recipientId,
      'is_typing': isTyping,
    }));
  }

  /// Fetch message history from REST API with E2EE decryption
  Future<List<ChatMessageModel>> getHistory(String matchId, {int limit = 50}) async {
    try {
      final response = await _client.get(
        '/api/v1/chat/history/$matchId',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ChatMessageModel.fromJson(
                  item as Map<String, dynamic>,
                  matchId: matchId,
                ))
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
    _statusController.close();
    _typingController.close();
  }
}

