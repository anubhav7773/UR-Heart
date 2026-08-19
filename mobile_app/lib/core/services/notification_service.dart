import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../navigation/nav_keys.dart';
import '../../features/chat/chat_screen.dart';

class NotificationRouter {
  /// Centralized handler for routing push notification clicks (Cold Start, Background, & Foreground)
  static void handleNotificationClick(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String? type = data['type']?.toString();
    final String? matchId = (data['match_id'] ?? data['conversation_id'])?.toString();
    final String? partnerId = (data['sender_id'] ?? data['partner_id'] ?? data['target_user_id'])?.toString();
    final String? partnerName = (data['sender_name'] ?? data['partner_name'] ?? data['title'])?.toString();
    final String partnerAvatar = data['partner_avatar']?.toString() ?? '';

    if (kDebugMode) {
      print('--> [NotificationRouter] Click: type=$type, matchId=$matchId, partnerId=$partnerId, partnerName=$partnerName');
    }

    final navState = rootNavigatorKey.currentState;
    if (navState == null) {
      if (kDebugMode) {
        print('--> [NotificationRouter] rootNavigatorKey is not mounted yet. Retrying after delay...');
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        _routeToDestination(type, matchId, partnerId, partnerName, partnerAvatar);
      });
      return;
    }

    _routeToDestination(type, matchId, partnerId, partnerName, partnerAvatar);
  }

  /// Parses payload string (e.g. from local notifications plugin tap)
  static void handlePayloadString(String? payloadStr) {
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final decoded = jsonDecode(payloadStr);
      if (decoded is Map<String, dynamic>) {
        final remoteMessage = RemoteMessage(data: decoded);
        handleNotificationClick(remoteMessage);
      }
    } catch (e) {
      if (kDebugMode) print('--> [NotificationRouter] Error parsing local payload: $e');
    }
  }

  static void _routeToDestination(
    String? type,
    String? matchId,
    String? partnerId,
    String? partnerName,
    String partnerAvatar,
  ) {
    if (matchId == null || matchId.isEmpty) {
      if (kDebugMode) print('--> [NotificationRouter] Missing matchId/conversationId, ignoring navigation.');
      return;
    }

    final navState = rootNavigatorKey.currentState;
    if (navState == null) return;

    final recipient = ChatRecipient(
      id: partnerId ?? '',
      name: (partnerName != null && partnerName.isNotEmpty) ? partnerName : 'Chat',
      avatarUrl: partnerAvatar,
    );

    // Push ChatScreen on TOP of the navigation stack to preserve Explore / Feed state
    navState.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          matchId: matchId,
          recipientUser: recipient,
          isDirectDM: type == 'direct_dm',
        ),
      ),
    );
  }

  static Future<void> setupNotificationListeners() async {
    // 1. App in Background & Tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationClick(message);
    });

    // 2. App Terminated & Opened via Notification Click
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Delay slightly to ensure widget tree & rootNavigatorKey are mounted
      Future.delayed(const Duration(milliseconds: 700), () {
        handleNotificationClick(initialMessage);
      });
    }
  }
}
