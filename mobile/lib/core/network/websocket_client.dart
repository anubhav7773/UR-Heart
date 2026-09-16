import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum MessageStatus { sent, delivered, read, error }

class ChatMessageModel {
  final String msgId;
  final String matchId;
  final String senderId;
  final String content;
  final MessageStatus status;
  final DateTime timestamp;

  ChatMessageModel({
    required this.msgId,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.timestamp,
  });
}

/// Resilient WebSocket Chat Client for UR-Heart
/// Handles auto-reconnect, message delivery receipts, and anti-leak violation events.
class ChatWebSocketClient {
  WebSocketChannel? _channel;
  final String wsBaseUrl;
  final Function(ChatMessageModel) onMessageReceived;
  final Function(String errorDetail) onAntiLeakViolation;
  final Function(String matchId, String token) onWhatsAppUnlocked;

  ChatWebSocketClient({
    required this.wsBaseUrl,
    required this.onMessageReceived,
    required this.onAntiLeakViolation,
    required this.onWhatsAppUnlocked,
  });

  void connect(String jwtToken) {
    final uri = Uri.parse('$wsBaseUrl/ws/chat?token=$jwtToken');
    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (rawData) {
          try {
            final data = jsonDecode(rawData as String) as Map<String, dynamic>;
            final event = data['event'];

            if (event == 'incoming_message') {
              onMessageReceived(ChatMessageModel(
                msgId: data['msg_id']?.toString() ?? '',
                matchId: data['match_id']?.toString() ?? '',
                senderId: data['sender_id']?.toString() ?? '',
                content: data['content'] ?? '',
                status: MessageStatus.delivered,
                timestamp: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
              ));
            } else if (event == 'anti_leak_violation') {
              onAntiLeakViolation(data['message'] ?? 'Contact sharing is prohibited.');
            } else if (event == 'whatsapp_unlocked') {
              onWhatsAppUnlocked(
                data['match_id']?.toString() ?? '',
                data['ephemeral_token']?.toString() ?? '',
              );
            }
          } catch (e) {
            debugPrint('Failed to parse incoming WebSocket message: $e');
          }
        },
        onError: (err) {
          debugPrint('WebSocket error: $err. Reconnecting in 5s...');
          Future.delayed(const Duration(seconds: 5), () => connect(jwtToken));
        },
        onDone: () {
          debugPrint('WebSocket disconnected.');
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  void sendMessage({
    required String matchId,
    required String recipientId,
    required String content,
  }) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'message',
        'match_id': matchId,
        'recipient_id': recipientId,
        'content': content,
      }));
    }
  }

  void sendReadReceipt(String matchId, {String? recipientId}) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'read_receipt',
        'match_id': matchId,
        if (recipientId != null) 'recipient_id': recipientId,
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
