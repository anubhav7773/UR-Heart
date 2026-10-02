import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Secure WSS Transport with Single-Use Ephemeral Handshake Tickets (DIS-06 Fix)
/// Obtains a short-lived (60-second) ephemeral ticket from POST /api/v1/chat/ws-ticket
/// before opening strictly encrypted wss:// channel. Never exposes long-lived tokens in query parameters.
class ChatWebSocketService {
  final Dio _dio;
  final String _baseWsHost; // e.g. "ur-heart.onrender.com"

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  Stream<Map<String, dynamic>> get eventStream => _messageStreamController.stream;
  bool get isConnected => _isConnected && _channel != null;

  ChatWebSocketService([Dio? dio, String? baseWsHost])
      : _dio = dio ?? Dio(),
        _baseWsHost = baseWsHost ?? _resolveWsHost(dio);

  static String _resolveWsHost(Dio? dio) {
    if (dio != null && dio.options.baseUrl.isNotEmpty) {
      try {
        final host = Uri.parse(dio.options.baseUrl).host.trim();
        // Never connect WSS to Vercel domains (e.g. app.urheart.asiverticals.me or *.vercel.app)
        // Vercel does not support persistent WebSocket connections.
        if (host.isNotEmpty && !host.contains('vercel') && !host.startsWith('app.')) {
          return host;
        }
      } catch (_) {}
    }
    return 'urheart.asiverticals.me';
  }

  /// Acquires single-use ephemeral ticket and opens secure WSS channel.
  Future<void> connectSecureChannel() async {
    if (_isDisposed || _channel != null) return;
    _reconnectTimer?.cancel();

    try {
      // 1. Fetch 60-second single-use ticket over authenticated HTTPS
      final ticketResponse = await _dio.post<Map<String, dynamic>>('/api/v1/chat/ws-ticket');
      final ticket = ticketResponse.data?['ticket'] as String?;
      if (ticket == null || ticket.isEmpty) {
        _handleDisconnect();
        return;
      }

      // 2. Open strictly encrypted WSS channel cross-platform (Web, Android, iOS)
      final wsUri = Uri.parse('wss://$_baseWsHost/ws/chat?ticket=$ticket');
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;
      _reconnectAttempts = 0;

      _channel?.stream.listen(
        (data) {
          final decoded = jsonDecode(data as String);
          if (decoded is Map<String, dynamic>) {
            _messageStreamController.add(decoded);
          }
        },
        onError: (_) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );

      _startPingLoop();
      debugPrint('ChatWebSocketService: secured WSS channel established at $wsUri');
    } catch (e) {
      debugPrint('ChatWebSocketService connection error: $e');
      _handleDisconnect();
    }
  }

  /// Backward-compatible connect invocation
  void connect() {
    connectSecureChannel();
  }

  void _startPingLoop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      sendJsonPayload({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()});
    });
  }

  void sendJsonPayload(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(payload));
      } catch (e) {
        debugPrint('ChatWebSocketService send error: $e');
      }
    }
  }

  /// Backward-compatible sendJson alias
  void sendJson(Map<String, dynamic> payload) {
    sendJsonPayload(payload);
  }

  void _handleDisconnect() {
    _isConnected = false;
    if (_isDisposed) return;
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;

    _reconnectAttempts++;
    final delayMs = _reconnectAttempts <= 1 ? 800 : (_reconnectAttempts <= 3 ? 1500 : 3000);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_isDisposed) {
        connectSecureChannel();
      }
    });
  }

  void disconnect() {
    _isDisposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageStreamController.close();
  }
}
