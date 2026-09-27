import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real-Time WebSocket client managing persistent connection, 25s heartbeat,
/// exponential backoff, and JSON wire protocol dispatch per Doc 05.
class ChatWebSocketService {
  final String _wsUrl;
  final String? _authToken;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelayMs = 30000;
  static const Duration _heartbeatInterval = Duration(seconds: 25);

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  ChatWebSocketService({
    String wsUrl = 'ws://10.0.2.2:8000/ws/chat',
    String? authToken,
  })  : _wsUrl = wsUrl,
        _authToken = authToken;

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  void connect() {
    if (_isDisposed) return;
    _cancelReconnectTimer();

    try {
      final tokenQuery = _authToken != null ? '?token=$_authToken' : '';
      final uri = Uri.parse('$_wsUrl$tokenQuery');
      _channel = WebSocketChannel.connect(uri);

      _channelSubscription = _channel?.stream.listen(
        _onMessageReceived,
        onError: _onConnectionError,
        onDone: _onConnectionClosed,
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _startHeartbeat();
      debugPrint('ChatWebSocketService: connected to $uri');
    } catch (e) {
      debugPrint('ChatWebSocketService connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      sendJson({'action': 'ping', 'timestamp': DateTime.now().toIso8601String()});
    });
  }

  void _onMessageReceived(dynamic rawData) {
    try {
      if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          _eventController.add(decoded);
        }
      }
    } catch (e) {
      debugPrint('ChatWebSocketService: json parse error $e');
    }
  }

  void _onConnectionError(dynamic error) {
    debugPrint('ChatWebSocketService: socket error $error');
    _scheduleReconnect();
  }

  void _onConnectionClosed() {
    debugPrint('ChatWebSocketService: connection closed');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _heartbeatTimer?.cancel();
    _channelSubscription?.cancel();
    _channel = null;

    final delayMs = min(1000 * pow(2, _reconnectAttempts).toInt(), _maxReconnectDelayMs);
    _reconnectAttempts++;
    debugPrint('ChatWebSocketService: reconnecting in ${delayMs}ms (attempt $_reconnectAttempts)');

    _cancelReconnectTimer();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_isDisposed) connect();
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  bool sendJson(Map<String, dynamic> data) {
    final channel = _channel;
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(data));
        return true;
      } catch (e) {
        debugPrint('ChatWebSocketService sendJson error: $e');
      }
    }
    return false;
  }

  void emitLocalEvent(Map<String, dynamic> event) {
    if (!_isDisposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _cancelReconnectTimer();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
