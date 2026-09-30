import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app/ur_heart_app.dart';

/// Ultra-Premium Outside-the-App Notification Service
/// Delivers WhatsApp-like heads-up notifications to Android system tray and lock screen
/// for mindful dialogues, mutual sparks, direct letters, and streak alerts.
class SanctuaryNotificationService {
  SanctuaryNotificationService._();
  static final SanctuaryNotificationService instance = SanctuaryNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String dialogueChannelId = 'ur_heart_sacred_dialogue';
  static const String dialogueChannelName = 'UR-Heart Sacred Dialogues';
  static const String dialogueChannelDesc =
      'Real-time alerts for mindful messages, mutual sparks, direct letters, and streaks.';

  static const String presenceChannelId = 'ur_heart_presence_channel';
  static const String presenceChannelName = 'Sanctuary Presence & Streaks';
  static const String presenceChannelDesc =
      'Mindful reminders for daily reflections, streaks, and sovereign sanctuary milestones.';

  /// Initialize local notification engine and register Android 13+ channels
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create High Importance Android Notification Channels (WhatsApp-grade priority)
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlatform != null) {
        // Request POST_NOTIFICATIONS permission on Android 13+
        await androidPlatform.requestNotificationsPermission();

        const dialogueChannel = AndroidNotificationChannel(
          dialogueChannelId,
          dialogueChannelName,
          description: dialogueChannelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        );

        const presenceChannel = AndroidNotificationChannel(
          presenceChannelId,
          presenceChannelName,
          description: presenceChannelDesc,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        );

        await androidPlatform.createNotificationChannel(dialogueChannel);
        await androidPlatform.createNotificationChannel(presenceChannel);
      }

      _isInitialized = true;
      debugPrint('[NOTIFICATIONS] SanctuaryNotificationService initialized successfully.');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Initialization warning: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final targetRoute = data['target_route'] as String? ?? '/main';

      if (targetRoute == '/chat-dialogue') {
        appNavigatorKey.currentState?.pushNamed(
          '/chat-dialogue',
          arguments: {
            'match_id': data['match_id'],
            'recipient_id': data['sender_id'],
            'recipient_name': data['sender_name'] ?? 'Seeker',
            'is_online': true,
          },
        );
      } else {
        appNavigatorKey.currentState?.pushNamed(targetRoute);
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Navigation payload dispatch error: $e');
    }
  }

  /// Show Ultra-Premium WhatsApp-like Heads-Up Notification
  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    String? subText,
    String? payload,
    String channelId = dialogueChannelId,
    String channelName = dialogueChannelName,
    Importance importance = Importance.max,
    Priority priority = Priority.high,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: dialogueChannelDesc,
      importance: importance,
      priority: priority,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: subText ?? 'UR-Heart Sanctuary',
      ),
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1B4332), // Sacred Pine
      enableLights: true,
      ledColor: const Color(0xFFD4AF37), // Sacred Gold
      ledOnMs: 500,
      ledOffMs: 500,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
      category: AndroidNotificationCategory.message,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Display notice error: $e');
    }
  }

  /// 💬 Ultra-Premium Chat Message Notification
  Future<void> showDialogueMessageNotification({
    required String senderName,
    required String messageText,
    required String matchId,
    required String senderId,
  }) async {
    final payload = jsonEncode({
      'target_route': '/chat-dialogue',
      'match_id': matchId,
      'sender_id': senderId,
      'sender_name': senderName,
    });

    await showSystemNotification(
      id: matchId.hashCode,
      title: '$senderName 💬',
      body: messageText,
      subText: 'Sacred Dialogue',
      payload: payload,
      channelId: dialogueChannelId,
      channelName: dialogueChannelName,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// ✨ Mutual Spark / Match Established Notification
  Future<void> showMutualSparkNotification({
    required String peerName,
    required String matchId,
    required String peerId,
  }) async {
    final payload = jsonEncode({
      'target_route': '/chat-dialogue',
      'match_id': matchId,
      'sender_id': peerId,
      'sender_name': peerName,
    });

    await showSystemNotification(
      id: ('spark_$matchId').hashCode,
      title: 'Resonance Established ✨',
      body: 'You and $peerName felt a mutual spark! Step inside to begin your dialogue.',
      subText: 'Mutual Spark',
      payload: payload,
      channelId: dialogueChannelId,
      channelName: dialogueChannelName,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// 💌 Direct Sanctuary Letter Notification
  Future<void> showDirectLetterNotification({
    required String senderName,
    required String messageSnippet,
    required String matchId,
    required String senderId,
  }) async {
    final payload = jsonEncode({
      'target_route': '/chat-dialogue',
      'match_id': matchId,
      'sender_id': senderId,
      'sender_name': senderName,
    });

    await showSystemNotification(
      id: ('direct_$matchId').hashCode,
      title: 'Direct Sanctuary Letter from $senderName 💌',
      body: messageSnippet.isNotEmpty
          ? messageSnippet
          : 'A seeker has dispatched an intentional direct note to your soul.',
      subText: 'Direct Letter',
      payload: payload,
      channelId: dialogueChannelId,
      channelName: dialogueChannelName,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// 🔥 24-Hour Streak Expiring Alert
  Future<void> showStreakAlertNotification({
    required int streakCount,
    required int hoursRemaining,
  }) async {
    final payload = jsonEncode({
      'target_route': '/growth',
    });

    await showSystemNotification(
      id: 9991,
      title: 'Mindful Presence Expiring 🔥',
      body: 'Your $streakCount-day flame will extinguish in $hoursRemaining hours. Take a gentle 10s reflection to preserve your sanctuary presence.',
      subText: 'Streak Defense',
      payload: payload,
      channelId: presenceChannelId,
      channelName: presenceChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
  }
}
