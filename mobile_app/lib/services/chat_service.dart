import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/network/api_client.dart';
import '../core/security/storage_manager.dart';

/// Secure Real-Time Chat WebSocket Connection Service
class ChatService {
  static final ChatService instance = ChatService._internal();
  factory ChatService() => instance;
  ChatService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  WebSocketChannel? get channel => _channel;

  /// Connect to secure match WebSocket with active JWT token handshake
  Future<WebSocketChannel?> connectToChatWebSocket({
    required String matchId,
    required Function(dynamic data) onDataReceived,
    Function(dynamic error)? onError,
    VoidCallback? onDone,
  }) async {
    try {
      disconnect();

      // 1. Get valid active JWT token
      final String? token = await StorageManager.instance.getAuthToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WS_ERROR] Cannot connect to chat: No active session token found');
        return null;
      }

      // 2. Build secure WebSocket URI
      final baseUri = Uri.parse(ApiClient.baseUrl);
      final isHttps = baseUri.scheme == 'https' || ApiClient.baseUrl.startsWith('https://');
      final wsScheme = isHttps ? 'wss' : 'ws';
      final wsHost = baseUri.host;
      final int port = baseUri.hasPort ? baseUri.port : 0;
      final wsPort = (port > 0 && port != 80 && port != 443) ? ':$port' : '';
      final wsUri = Uri.parse(
        '$wsScheme://$wsHost$wsPort/api/v1/chat/ws/$matchId?token=${Uri.encodeComponent(token)}',
      );

      debugPrint('[WS_CONNECT] Connecting to secure match room: $matchId');

      // 3. Connect
      _channel = IOWebSocketChannel.connect(
        wsUri,
        pingInterval: const Duration(seconds: 15),
      );
      _subscription = _channel?.stream.listen(
        (data) {
          try {
            onDataReceived(data);
          } catch (e) {
            debugPrint('[WS_DATA_ERROR] $e');
          }
        },
        onError: (err) {
          debugPrint('[WS_ERROR] $err');
          if (onError != null) onError(err);
        },
        onDone: () {
          debugPrint('[WS_CLOSED] Match room $matchId connection closed');
          if (onDone != null) onDone();
        },
        cancelOnError: false,
      );

      return _channel;
    } catch (e) {
      debugPrint('[WS_CONNECTION_ERROR] Failed to establish secure WebSocket: $e');
      return null;
    }
  }

  /// Disconnect and cleanup active WebSocket stream
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
