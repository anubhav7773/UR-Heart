import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real-Time WebSocket Service with 25s ping-pong keepalive and 3-stage delivery ticks
class WebSocketChatService {
  static final WebSocketChatService instance = WebSocketChatService._internal();
  WebSocketChatService._internal();
  factory WebSocketChatService() => instance;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  final StreamController<Map<String, dynamic>> _incomingEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _incomingEventsController.stream;

  void connect({required String token, required String serverUrl}) {
    if (_channel != null) return;

    try {
      final wsUri = Uri.parse('$serverUrl/ws/chat?token=$token');
      _channel = WebSocketChannel.connect(wsUri);

      _channel?.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            _incomingEventsController.add(parsed);
          } catch (_) {}
        },
        onError: (_) => _reconnect(token, serverUrl),
        onDone: () => _reconnect(token, serverUrl),
      );

      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect(token, serverUrl);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 25-Second Heartbeat to prevent Render proxy socket closure
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      sendMessagePayload({
        'type': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  void sendMessagePayload(Map<String, dynamic> payload) {
    if (_channel != null) {
      _channel?.sink.add(jsonEncode(payload));
    }
  }

  void markMessageRead({required int messageId, required String matchId}) {
    sendMessagePayload({
      'type': 'status_update',
      'status': 'read',
      'message_id': messageId,
      'match_id': matchId,
    });
  }

  void _reconnect(String token, String serverUrl) {
    disconnect();
    _scheduleReconnect(token, serverUrl);
  }

  void _scheduleReconnect(String token, String serverUrl) {
    Timer(const Duration(seconds: 3), () => connect(token: token, serverUrl: serverUrl));
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
  }
}
