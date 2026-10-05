import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/ur_heart_app.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_session_storage.dart';
import '../../features/chat/presentation/services/web_security_stub.dart'
    if (dart.library.js_interop) '../../features/chat/presentation/services/web_security_web.dart';

/// Ultra-Premium Outside-the-App Notification Service
/// Delivers WhatsApp-like heads-up notifications to Android system tray and lock screen
/// for mindful dialogues, mutual sparks, direct letters, and streak alerts.
class SanctuaryNotificationService {
  SanctuaryNotificationService._();
  static final SanctuaryNotificationService instance = SanctuaryNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  static const String _pendingFcmRegistrationKey =
      'ur_heart_fcm_registration_pending';
  final Set<String> _seenNotificationIds = {};

  /// Checks if notification was already presented on this device within the active session.
  /// Prevents double-notification when both WebSocket and FCM deliver the same event.
  bool markNotificationSeen(String? notifId) {
    if (notifId == null || notifId.isEmpty) return false;
    if (_seenNotificationIds.contains(notifId)) return true;
    _seenNotificationIds.add(notifId);
    if (_seenNotificationIds.length > 500) {
      _seenNotificationIds.clear();
    }
    return false;
  }

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

        // Explicitly request Android 13+ (API 33+) POST_NOTIFICATIONS runtime permission
        await androidPlatform.requestNotificationsPermission();
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
      final notifId = message.data['notif_id']?.toString() ?? message.messageId;
      if (notifId != null && markNotificationSeen(notifId)) {
        return;
      }
      final notif = message.notification;
      final title = notif?.title ?? message.data['title']?.toString();
      final body = notif?.body ?? message.data['body']?.toString();
      if (title != null && title.isNotEmpty) {
        final notifType = message.data['type']?.toString().toLowerCase() ?? '';
        final isStreak = notifType.contains('streak');
        showSystemNotification(
          id: notifId?.hashCode ?? message.hashCode,
          title: title,
          body: body ?? '',
          payload: jsonEncode(message.data),
          channelId: isStreak ? presenceChannelId : dialogueChannelId,
          channelName: isStreak ? presenceChannelName : dialogueChannelName,
        );
      }
    });

    // Background push tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNavigationData(message.data);
    });

    // Handle push notification tap when the app was launched from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNavigationData(message.data);
        });
      }
    });
  } catch (fcmError) {
    debugPrint('[FCM INIT NOTICE] $fcmError');
  }

  _isInitialized = true;
}

  static Future<void> _registerFcmTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ur_heart_fcm_token', token);

      String? authToken;
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          authToken = await fbUser.getIdToken();
          if (authToken != null && authToken.isNotEmpty) {
            await SecureSessionStorage.instance.saveAuthToken(authToken);
          }
        }
      } catch (_) {}

      if (authToken == null || authToken.isEmpty) {
        final secureToken = await SecureSessionStorage.instance.getAuthToken();
        authToken = (secureToken != null && secureToken.isNotEmpty)
            ? secureToken
            : (prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token'));
      }

      if (authToken != null && authToken.isNotEmpty) {
        await _dispatchTokenToBackend(token, authToken);
        await prefs.setBool(_pendingFcmRegistrationKey, false);
        debugPrint('[FCM REGISTER] Token registered with backend successfully.');
      } else {
        await prefs.setBool(_pendingFcmRegistrationKey, true);
      }
    } catch (e) {
      debugPrint('[FCM REGISTER NOTICE] $e');
    }
  }

  static void syncStoredFcmToken([String? explicitAuthToken]) {
    Future<void>.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('ur_heart_fcm_token');
        if (token == null || token.isEmpty) {
          if (!kIsWeb) {
            token = await FirebaseMessaging.instance.getToken();
            if (token != null && token.isNotEmpty) {
              await prefs.setString('ur_heart_fcm_token', token);
            }
          }
        }
        if (token == null || token.isEmpty) return;

        String? authToken = explicitAuthToken;
        if (authToken == null || authToken.isEmpty) {
          try {
            final fbUser = FirebaseAuth.instance.currentUser;
            if (fbUser != null) {
              authToken = await fbUser.getIdToken();
              if (authToken != null && authToken.isNotEmpty) {
                await SecureSessionStorage.instance.saveAuthToken(authToken);
              }
            }
          } catch (_) {}
        }

        if (authToken == null || authToken.isEmpty) {
          final secureToken = await SecureSessionStorage.instance.getAuthToken();
          authToken = (secureToken != null && secureToken.isNotEmpty)
              ? secureToken
              : (prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token'));
        }

        if (authToken != null && authToken.isNotEmpty) {
          await _dispatchTokenToBackend(token, authToken);
          await prefs.setBool(_pendingFcmRegistrationKey, false);
        }
      } catch (e) {
        debugPrint('[FCM SYNC NOTICE] $e');
      }
    });
  }

  /// Safely requests notification permissions on Web upon explicit user interaction
  Future<bool> requestWebNotificationPermission() async {
    try {
      if (kIsWeb) {
        await requestBrowserNotificationPermission();
      } else {
        final androidPlatform = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlatform?.requestNotificationsPermission();
      }

      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        try {
          final token = await fcm.getToken();
          if (token != null && token.isNotEmpty) {
            await _registerFcmTokenWithBackend(token);
          }
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Web permission request note: $e');
    }
    return false;
  }

  static Future<void> _dispatchTokenToBackend(String token, String authToken) async {
    final candidateUrls = [
      ApiEndpoints.defaultBaseUrl,
      'https://urheart.asiverticals.me',
      'https://ur-heart.onrender.com',
    ];
    String currentAuthToken = authToken;
    for (final base in candidateUrls) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'Authorization': 'Bearer $currentAuthToken'},
        ));
        final resp = await dio.post<dynamic>(
          '/api/v1/notifications/register-token',
          data: {
            'fcm_token': token,
            'platform': kIsWeb ? 'web' : 'android',
          },
        );
        if (resp.statusCode == 200) {
          debugPrint('[FCM DISPATCH] Successfully linked token to $base');
          return;
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          try {
            final fbUser = FirebaseAuth.instance.currentUser;
            if (fbUser != null) {
              final fresh = await fbUser.getIdToken(true);
              if (fresh != null && fresh.isNotEmpty) {
                currentAuthToken = fresh;
                await SecureSessionStorage.instance.saveAuthToken(fresh);
                final retryDio = Dio(BaseOptions(
                  baseUrl: base,
                  connectTimeout: const Duration(seconds: 5),
                  receiveTimeout: const Duration(seconds: 5),
                  headers: {'Authorization': 'Bearer $currentAuthToken'},
                ));
                final retryResp = await retryDio.post<dynamic>(
                  '/api/v1/notifications/register-token',
                  data: {
                    'fcm_token': token,
                    'platform': kIsWeb ? 'web' : 'android',
                  },
                );
                if (retryResp.statusCode == 200) {
                  debugPrint('[FCM DISPATCH] Successfully linked refreshed token to $base');
                  return;
                }
              }
            }
          } catch (_) {}
        }
        debugPrint('[FCM DISPATCH NOTICE] Failed dispatching to $base: $dioErr');
      } catch (e) {
        debugPrint('[FCM DISPATCH NOTICE] Failed dispatching to $base: $e');
      }
    }
  }

  void _handleNavigationData(Map<String, dynamic> data) {
    try {
      const allowedRoutes = {
        '/main',
        '/chat-dialogue',
        '/resonances',
        '/growth-hub',
        '/streaks',
      };
      final requestedRoute = data['target_route'];
      final targetRoute = requestedRoute is String &&
              allowedRoutes.contains(requestedRoute)
          ? requestedRoute
          : '/main';
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

  /// Safely shows notifications in a background isolate without requesting UI permissions
  Future<void> showBackgroundNotification({
    required int id,
    required String title,
    required String body,
    String? subText,
    String? payload,
    String channelId = dialogueChannelId,
    String channelName = dialogueChannelName,
  }) async {
    if (kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(settings: initSettings);

      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        const dialogueChannel = AndroidNotificationChannel(
          dialogueChannelId,
          dialogueChannelName,
          description: dialogueChannelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        );
        await androidPlatform.createNotificationChannel(dialogueChannel);
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: dialogueChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: subText ?? 'UR-Heart Sanctuary',
        ),
        icon: '@drawable/ic_stat_urheart',
        color: const Color(0xFF1B4332), // Sacred Pine
        enableLights: true,
        ledColor: const Color(0xFFD4AF37), // Sacred Gold
        ledOnMs: 500,
        ledOffMs: 500,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
        category: AndroidNotificationCategory.message,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Background notification display error: $e');
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
    if (kIsWeb) {
      showBrowserNotification(title, body);
      return;
    }
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
      icon: '@drawable/ic_stat_urheart',
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

  /// ðŸ’¬ Ultra-Premium Chat Message Notification
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
      title: '$senderName ðŸ’¬',
      body: messageText,
      subText: 'Sacred Dialogue',
      payload: payload,
      channelId: dialogueChannelId,
      channelName: dialogueChannelName,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// âœ¨ Mutual Spark / Match Established Notification
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
      title: 'Resonance Established âœ¨',
      body: 'You and $peerName felt a mutual spark! Step inside to begin your dialogue.',
      subText: 'Mutual Spark',
      payload: payload,
      channelId: dialogueChannelId,
      channelName: dialogueChannelName,
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// ðŸ’Œ Direct Sanctuary Letter Notification
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
      title: 'Direct Sanctuary Letter from $senderName ðŸ’Œ',
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

  /// ðŸ”¥ 24-Hour Streak Expiring Alert
  Future<void> showStreakAlertNotification({
    required int streakCount,
    required int hoursRemaining,
    String? title,
    String? body,
  }) async {
    final payload = jsonEncode({
      'target_route': '/growth',
    });

    await showSystemNotification(
      id: 9991,
      title: title ?? 'Mindful Presence Expiring ðŸ”¥',
      body: body ??
          'Your $streakCount-day flame will extinguish in $hoursRemaining hours. Take a gentle 10s reflection to preserve your sanctuary presence.',
      subText: 'Streak Defense',
      payload: payload,
      channelId: presenceChannelId,
      channelName: presenceChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// ðŸŒŸ 24-Hour Streak Claimed & Secured Celebration
  Future<void> showStreakSecuredNotification({
    required int streakCount,
    String? title,
    String? body,
    int? boostPoints,
  }) async {
    final payload = jsonEncode({
      'target_route': '/growth',
    });

    await showSystemNotification(
      id: 9992,
      title: title ?? 'ðŸ”¥ Day $streakCount Streak Secured!',
      body: body ??
          'You earned +${boostPoints ?? 1} Boost Point! Your profile is prioritized at the top of the discovery deck for 24 hours.',
      subText: 'Mindful Sanctuary',
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

  /// Unregisters FCM device token on backend and clears local cache on user logout
  Future<void> unregisterFcmToken([String? explicitAuthToken]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('ur_heart_fcm_token');
      await prefs.remove('ur_heart_fcm_token');

      String? authToken = explicitAuthToken;
      if (authToken == null || authToken.isEmpty) {
        authToken = await SecureSessionStorage.instance.getAuthToken();
      }
      if (authToken == null || authToken.isEmpty) {
        authToken = prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token');
      }

      if (authToken != null && authToken.isNotEmpty) {
        final candidateUrls = [
          ApiEndpoints.defaultBaseUrl,
          'https://urheart.asiverticals.me',
          'https://ur-heart.onrender.com',
        ];
        for (final base in candidateUrls) {
          try {
            final dio = Dio(BaseOptions(
              baseUrl: base,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              headers: {'Authorization': 'Bearer $authToken'},
            ));
            await dio.post<dynamic>(
              '/api/v1/notifications/unregister-token',
              data: {'fcm_token': token ?? ''},
            );
            debugPrint('[NOTIFICATIONS] Device token unregistered from backend.');
            break;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] unregisterFcmToken notice: $e');
    }
  }

  /// Checks server-side push authorization status and token registration status
  Future<Map<String, dynamic>> checkPushHealth() async {
    String? authToken;
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        authToken = await fbUser.getIdToken();
      }
    } catch (_) {}
    if (authToken == null || authToken.isEmpty) {
      authToken = await SecureSessionStorage.instance.getAuthToken();
    }
    if (authToken == null || authToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token');
    }
    if (authToken == null || authToken.isEmpty) {
      return {'status': 'unauthenticated', 'message': 'Please sign in first.'};
    }

    final candidateUrls = [
      ApiEndpoints.defaultBaseUrl,
      'https://urheart.asiverticals.me',
      'https://ur-heart.onrender.com',
    ];
    for (final base in candidateUrls) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          headers: {'Authorization': 'Bearer $authToken'},
        ));
        final resp = await dio.get<dynamic>('/api/v1/notifications/push-health');
        if (resp.statusCode == 200 && resp.data is Map) {
          return Map<String, dynamic>.from(resp.data as Map);
        }
      } catch (_) {}
    }
    return {'status': 'error', 'message': 'Could not connect to sanctuary servers.'};
  }

  /// Sends a real test push notification from the server directly to this device
  Future<Map<String, dynamic>> sendTestPush() async {
    String? authToken;
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        authToken = await fbUser.getIdToken();
      }
    } catch (_) {}
    if (authToken == null || authToken.isEmpty) {
      authToken = await SecureSessionStorage.instance.getAuthToken();
    }
    if (authToken == null || authToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('ur_heart_auth_token') ?? prefs.getString('auth_token');
    }
    if (authToken == null || authToken.isEmpty) {
      return {'ok': false, 'error': 'Please sign in first.'};
    }

    final candidateUrls = [
      ApiEndpoints.defaultBaseUrl,
      'https://urheart.asiverticals.me',
      'https://ur-heart.onrender.com',
    ];
    for (final base in candidateUrls) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Authorization': 'Bearer $authToken'},
        ));
        final resp = await dio.post<dynamic>('/api/v1/notifications/test-push');
        if (resp.statusCode == 200 && resp.data is Map) {
          return Map<String, dynamic>.from(resp.data as Map);
        }
      } catch (e) {
        debugPrint('[NOTIFICATIONS] sendTestPush error on $base: $e');
      }
    }
    return {'ok': false, 'error': 'Failed to dispatch test push notification.'};
  }
}

