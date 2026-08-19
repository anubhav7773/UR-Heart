import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import 'chat_screen.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  final Set<String> _uniqueMessageIds = {};
  bool _isLoading = false;
  String _currentUserId = '';
  String? _lastErrorCode;
  String? _lastErrorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get currentUserId => _currentUserId;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastErrorMessage => _lastErrorMessage;
  void clearLastError() { _lastErrorCode = null; _lastErrorMessage = null; notifyListeners(); }

  static double calculateHaversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double R = 6371.0;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static String getFormattedDistanceLabel(double distKm) {
    if (distKm < 1.0) {
      return "Less than 1 km away";
    } else if (distKm <= 2.0) {
      return "Within 2 km";
    } else if (distKm <= 5.0) {
      return "Within 5 km";
    } else if (distKm <= 10.0) {
      return "Within 10 km";
    } else {
      return "Within ${distKm.ceil()} km";
    }
  }

  Future<void> initialize() async {
    _currentUserId = await StorageManager.instance.getUserId() ?? '';
    notifyListeners();
  }

  void setMessages(List<ChatMessage> newMessages) {
    _uniqueMessageIds.clear();
    _messages = [];
    for (final message in newMessages) {
      _upsertMessage(message);
    }
    notifyListeners();
  }

  void appendMessage(ChatMessage message) {
    if (_upsertMessage(message)) {
      notifyListeners();
    }
  }

  void appendMessages(List<ChatMessage> newMessages) {
    bool updated = false;
    for (var m in newMessages) {
      if (_upsertMessage(m)) {
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  bool _upsertMessage(ChatMessage message) {
    if (_uniqueMessageIds.contains(message.id)) return false;
    final clientMsgId = message.clientMsgId;
    final optimisticIndex = clientMsgId == null
        ? -1
        : _messages.indexWhere((existing) =>
            existing.id == clientMsgId || existing.clientMsgId == clientMsgId);
    if (optimisticIndex != -1) {
      _messages[optimisticIndex] = message;
    } else {
      _messages.add(message);
    }
    _uniqueMessageIds.add(message.id);
    if (clientMsgId != null) _uniqueMessageIds.add(clientMsgId);
    return true;
  }

  Future<void> fetchMessages(String matchId, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      if (_currentUserId.isEmpty) {
        _currentUserId = await StorageManager.instance.getUserId() ?? '';
      }

      final response = await ApiClient.instance.getMessages(matchId);
      // Handle response.data being a raw JSON string
      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (_) {}
      }
      if (responseData != null && responseData is Map && responseData['data'] != null) {
        final List<dynamic> rawMsgs = responseData['data'] is List
            ? responseData['data']
            : [];
        final List<ChatMessage> parsedList = [];

        for (var item in rawMsgs) {
          if (item is Map) {
            try {
              parsedList.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
        }

        if (!silent || _messages.isEmpty) {
          setMessages(parsedList);
        } else {
          appendMessages(parsedList);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ChatProvider] Error fetching messages: $e');
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> sendMessage({
    required String matchId,
    required String content,
    String? mediaUrl,
  }) async {
    final String clientMsgId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final String actualSenderId = _currentUserId.isNotEmpty ? _currentUserId : 'current_user_id';

    final optimisticMessage = ChatMessage(
      id: clientMsgId,
      clientMsgId: clientMsgId,
      senderId: actualSenderId,
      text: content,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      isSent: false,
    );

    appendMessage(optimisticMessage);

    try {
      final response = await ApiClient.instance.sendMessage(
        matchId: matchId,
        clientMsgId: clientMsgId,
        content: content,
        mediaUrl: mediaUrl,
      );

      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        final String serverId = data['id'] ?? clientMsgId;
        if (serverId != clientMsgId) {
          final index = _messages.indexWhere((m) => m.id == clientMsgId || m.clientMsgId == clientMsgId);
          if (index != -1) {
            _uniqueMessageIds.add(serverId);
            _messages[index] = ChatMessage(
              id: serverId,
              clientMsgId: clientMsgId,
              senderId: actualSenderId,
              text: content,
              mediaUrl: mediaUrl,
              timestamp: _parseResponseTimestamp(data['created_at'], optimisticMessage.timestamp),
              isSent: true,
            );
            notifyListeners();
          }
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[ChatProvider] Error sending message: $e');
      }

      // Rollback optimistic message if still present
      final index = _messages.indexWhere((m) => m.id == clientMsgId || m.clientMsgId == clientMsgId);
      if (index != -1) {
        _messages.removeAt(index);
      }
      _uniqueMessageIds.remove(clientMsgId);

      String? code;
      String? detail;

      if (e is DioException && e.response != null) {
        final resData = e.response?.data;
        if (resData is Map) {
          code = resData['error_code'] ?? (resData['error'] is Map ? resData['error']['error_code'] : null);
          detail = resData['detail'] ?? (resData['error'] is Map ? resData['error']['detail'] : null) ?? resData['message'];
        }
      }

      // If Safe Bridge enforcement triggered, provide haptic feedback and surface the error to UI
      if (code != null && code == 'SAFE_BRIDGE_LOCKED') {
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
        _lastErrorCode = code;
        _lastErrorMessage = detail ?? 'Safe Bridge locked. Unlock to share contact details.';
        notifyListeners();
        return false;
      }

      // Generic failure
      _lastErrorCode = null;
      _lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unsendMessage(String messageId) async {
    try {
      final response = await ApiClient.instance.unsendMessage(messageId: messageId);
      if (response.statusCode == 200 || (response.data != null && response.data['success'] == true)) {
        _messages.removeWhere((m) => m.id == messageId || m.clientMsgId == messageId);
        _uniqueMessageIds.remove(messageId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[ChatProvider] Error un-sending message: $e');
      }
      return false;
    }
  }

  DateTime _parseResponseTimestamp(dynamic value, DateTime fallback) {
    try {
      return DateTime.parse(value?.toString() ?? '').toLocal();
    } on FormatException {
      return fallback;
    }
  }

  void clear() {
    _messages.clear();
    _uniqueMessageIds.clear();
    _isLoading = false;
    notifyListeners();
  }
}
