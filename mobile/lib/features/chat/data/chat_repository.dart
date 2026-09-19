import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/chat_crypto_service.dart';

class MatchConversationModel {
  final String matchId;
  final String partnerId;
  final String partnerName;
  final String partnerCity;
  final String? partnerPhoto;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool whatsappUnlocked;

  MatchConversationModel({
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerCity,
    this.partnerPhoto,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.whatsappUnlocked,
  });

  factory MatchConversationModel.fromJson(Map<String, dynamic> json) {
    return MatchConversationModel(
      matchId: json['match_id']?.toString() ?? '',
      partnerId: json['partner_id']?.toString() ?? '',
      partnerName: json['partner_name'] ?? 'Anonymous',
      partnerCity: json['partner_city'] ?? '',
      partnerPhoto: json['partner_photo'] ?? json['partner_photo_url'],
      lastMessage: json['last_message'] ?? '',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      whatsappUnlocked: json['whatsapp_unlocked'] ?? false,
    );
  }
}

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
    this.status = 'sent',
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
    final rawContent = json['encrypted_text']?.toString() ?? json['content']?.toString() ?? '';
    final decryptedContent = ChatCryptoService.decryptMessage(rawContent, mId);

    return ChatMessageModel(
      id: json['id']?.toString() ?? json['msg_id']?.toString() ?? UniqueKey().toString(),
      matchId: mId,
      senderId: json['sender_id']?.toString() ?? '',
      content: decryptedContent,
      status: json['status']?.toString() ?? 'sent',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }
}

class ChatRepository {
  final Dio _dio;
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

  ChatRepository({Dio? dio}) : _dio = dio ?? createApiClient();

  Future<Options> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<MatchConversationModel>> fetchMatches() async {
    try {
      final response = await _dio.get('/api/v1/chat/matches', options: await _authHeaders());
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => MatchConversationModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching matches: $e');
      return [];
    }
  }

  Future<List<ChatMessageModel>> fetchHistory(String matchId) async {
    try {
      final response = await _dio.get(
        '/api/v1/chat/history/$matchId?limit=50',
        options: await _authHeaders(),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>, matchId: matchId))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  Future<List<ChatMessageModel>> getHistory(String matchId, {int limit = 50}) async {
    return fetchHistory(matchId);
  }

  Future<void> connect() async {
    try {
      String token = '';
      try {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken() ?? '';
      } catch (_) {}
      final baseWs = EnvConfig.wsBaseUrl.isNotEmpty ? EnvConfig.wsBaseUrl : 'wss://ur-heart.onrender.com';
      final wsUri = Uri.parse('$baseWs/ws/chat?token=$token');

      _channel = WebSocketChannel.connect(wsUri);
      _channel?.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
            final event = (jsonMap['event'] ?? jsonMap['type']) as String?;

            if (event == 'anti_leak_violation' || event == 'error') {
              final reason = jsonMap['message'] as String? ??
                  jsonMap['detail'] as String? ??
                  'Sharing personal contact details is prohibited.';
              _antiLeakAlertController.add(reason);
            } else if (event == 'incoming_message' || event == 'new_message') {
              final msg = ChatMessageModel.fromJson(jsonMap);
              _messageController.add(msg);
            } else if (event == 'message_sent') {
              _statusController.add({
                'type': 'message_sent',
                'msg_id': jsonMap['msg_id'] ?? jsonMap['id'],
                'match_id': jsonMap['match_id'],
                'status': jsonMap['status'] ?? 'sent',
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
      );
    } catch (e) {
      debugPrint('Failed to connect to Chat WebSocket: $e');
    }
  }

  void sendMessage({
    required String matchId,
    required String recipientId,
    required String content,
  }) {
    if (_channel == null) return;
    _channel?.sink.add(jsonEncode({
      'type': 'message',
      'match_id': matchId,
      'recipient_id': recipientId,
      'content': content,
    }));
  }

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

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
    _antiLeakAlertController.close();
    _statusController.close();
    _typingController.close();
  }
}
