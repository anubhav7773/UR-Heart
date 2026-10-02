import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Initialize local notification engine, register Android 13+ channels, and initialize FCM (Web + Android)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
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
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Local notifications plugin notice: $e');
    }
  }

    // Initialize Firebase Cloud Messaging for outside-the-app push notifications (Web + Native)
    try {
      final fcm = FirebaseMessaging.instance;
      if (!kIsWeb) {
        await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        final token = await fcm.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('[FCM] Device Token: ...${token.substring(token.length - 8)}');
          _registerFcmTokenWithBackend(token);
        }
      }

      fcm.onTokenRefresh.listen((newToken) {
        _registerFcmTokenWithBackend(newToken);
      });

    // Foreground push message listener: Show system notification immediately
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif != null) {
        showSystemNotification(
          id: message.hashCode,
          title: notif.title ?? 'UR-Heart Notification',
          body: notif.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    });

    // Background push tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNavigationData(message.data);
    });
  } catch (fcmError) {
    debugPrint('[FCM INIT NOTICE] $fcmError');
  }

  _isInitialized = true;
  debugPrint('[NOTIFICATIONS] SanctuaryNotificationService initialized successfully.');
}

  static Future<void> _registerFcmTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_fcm_token', token);
      final authToken = prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token');
      if (authToken != null && authToken.isNotEmpty) {
        await _dispatchTokenToBackend(token, authToken);
        debugPrint('[FCM REGISTER] Token registered with backend successfully.');
      }
    } catch (e) {
      debugPrint('[FCM REGISTER NOTICE] $e');
    }
  }

  static void syncStoredFcmToken(String authToken) {
    SharedPreferences.getInstance().then((prefs) {
      final token = prefs.getString('ur_heart_fcm_token');
      if (token != null && token.isNotEmpty) {
        _dispatchTokenToBackend(token, authToken).ignore();
      }
    });
  }

  /// Safely requests notification permissions on Web upon explicit user interaction
  Future<bool> requestWebNotificationPermission() async {
    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await fcm.getToken();
        if (token != null && token.isNotEmpty) {
          _registerFcmTokenWithBackend(token);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Web permission request note: $e');
    }
    return false;
  }

  static Future<void> _dispatchTokenToBackend(String token, String authToken) async {
    final candidateUrls = [
      'https://app.urheart.asiverticals.me',
      'https://ur-heart.onrender.com',
      'https://urheart.asiverticals.me',
    ];
    for (final base in candidateUrls) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {'Authorization': 'Bearer $authToken'},
        ));
        final resp = await dio.post<dynamic>(
          '/api/v1/notifications/register-token',
          data: {'fcm_token': token},
        );
        if (resp.statusCode == 200) {
          debugPrint('[FCM DISPATCH] Successfully linked token to $base');
          return;
        }
      } catch (_) {}
    }
  }

  void _handleNavigationData(Map<String, dynamic> data) {
    try {
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

  void _onNotificationTapped(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      _handleNavigationData(data);
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Tap decode error: $e');
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
    if (kIsWeb) return;
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
      enableVibration: !kIsWeb,
      vibrationPattern: kIsWeb ? null : Int64List.fromList([0, 250, 200, 250]),
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

  /// Cancels all active system tray notifications on user logout or session reset
  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[NOTIFICATIONS] All active system tray notifications dismissed.');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] cancelAll warning: $e');
    }
  }
}

