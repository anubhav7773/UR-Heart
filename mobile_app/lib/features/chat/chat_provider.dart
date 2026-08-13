import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import 'chat_screen.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  final Set<String> _uniqueMessageIds = {};
  bool _isLoading = false;
  String _currentUserId = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get currentUserId => _currentUserId;

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
    _messages = newMessages.where((m) => _uniqueMessageIds.add(m.id)).toList();
    notifyListeners();
  }

  void appendMessage(ChatMessage message) {
    if (_uniqueMessageIds.add(message.id)) {
      _messages.add(message);
      notifyListeners();
    }
  }

  void appendMessages(List<ChatMessage> newMessages) {
    bool updated = false;
    for (var m in newMessages) {
      if (_uniqueMessageIds.add(m.id)) {
        _messages.add(m);
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
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
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> rawMsgs = response.data['data'];
        final List<ChatMessage> parsedList = [];

        for (var item in rawMsgs) {
          final String msgId = item['id'] ?? '';
          if (msgId.isNotEmpty) {
            final String rawTime = item['created_at'] ?? '';
            final parsedDt = DateTime.tryParse(rawTime);
            parsedList.add(
              ChatMessage(
                id: msgId,
                senderId: item['sender_id'] ?? '',
                text: item['content'] ?? '',
                mediaUrl: item['media_url'],
                timestamp: parsedDt != null ? parsedDt.toLocal() : DateTime.now(),
              ),
            );
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
    final String clientMsgId = 'client_${DateTime.now().millisecondsSinceEpoch}_${_messages.length}';
    final String actualSenderId = _currentUserId.isNotEmpty ? _currentUserId : 'current_user_id';

    final optimisticMessage = ChatMessage(
      id: clientMsgId,
      senderId: actualSenderId,
      text: content,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
    );

    appendMessage(optimisticMessage);

    try {
      final response = await ApiClient.instance.sendMessage(
        matchId: matchId,
        content: content,
        mediaUrl: mediaUrl,
      );

      if (response.data != null && response.data['data'] != null) {
        final String serverId = response.data['data']['id'] ?? clientMsgId;
        if (serverId != clientMsgId) {
          final index = _messages.indexWhere((m) => m.id == clientMsgId);
          if (index != -1) {
            _uniqueMessageIds.remove(clientMsgId);
            _uniqueMessageIds.add(serverId);
            _messages[index] = ChatMessage(
              id: serverId,
              senderId: actualSenderId,
              text: content,
              mediaUrl: mediaUrl,
              timestamp: optimisticMessage.timestamp,
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
      return false;
    }
  }

  void clear() {
    _messages.clear();
    _uniqueMessageIds.clear();
    _isLoading = false;
    notifyListeners();
  }
}
