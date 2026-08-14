import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../security/storage_manager.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('FCM Background Message Received: ${message.messageId}');
    print('Title: ${message.notification?.title}, Body: ${message.notification?.body}');
  }
}

class FcmService {
  static final FcmService instance = FcmService._internal();
  factory FcmService() => instance;

  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for urgent match and chat push notifications.',
    importance: Importance.max,
    playSound: true,
  );

  String? _fcmToken;
  GlobalKey<ScaffoldMessengerState>? _foregroundMessengerKey;
  GlobalKey<NavigatorState>? _navigatorKey;

  String? get fcmToken => _fcmToken;

  Future<void> initialize({
    GlobalKey<ScaffoldMessengerState>? foregroundMessengerKey,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _foregroundMessengerKey = foregroundMessengerKey;
    _navigatorKey = navigatorKey;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      // 1. Request Explicit Notification Permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('FCM Permission Status: ${settings.authorizationStatus}');
      }

      // 2. Setup Local Notification Channel for Android Popups
      await _setupLocalNotificationChannel();

      // 3. Fetch FCM Token & Sync to Backend
      _fcmToken = await _fcm.getToken();
      if (kDebugMode) {
        print('FCM Device Token: $_fcmToken');
      }
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        await _syncTokenToBackend(_fcmToken!);
      }

      // Token Refresh Listener
      _fcm.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _syncTokenToBackend(newToken);
      });

      // 4. Foreground Message Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        if (kDebugMode) {
          print('FCM Foreground Message Received: ${notification?.title} - ${notification?.body} | Data: $data');
        }

        _showLocalNotification(message);
        _showForegroundSnackBar(message);
      });

      // 5. Background App Launch via Notification Tap Handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('FCM App Opened from Notification Tap: ${message.data}');
        }
        _handleNotificationTap(message);
      });

      // 6. Cold Launch via Notification Tap Handler
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('FCM Cold Launch from Notification Tap: ${initialMessage.data}');
        }
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FCM Service Initialization notice: $e');
      }
    }
  }

  Future<void> _setupLocalNotificationChannel() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            print('Local Notification Tapped with payload: ${response.payload}');
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_highImportanceChannel);
    } catch (e) {
      if (kDebugMode) {
        print('Failed setting up local notification channel: $e');
      }
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    try {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'New Notification';
      final body = notification?.body ?? message.data['body'] ?? '';

      _localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _highImportanceChannel.id,
            _highImportanceChannel.name,
            channelDescription: _highImportanceChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing local notification popup: $e');
      }
    }
  }

  void _showForegroundSnackBar(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final messenger = _foregroundMessengerKey?.currentState;

    if (messenger != null && (notification != null || data.isNotEmpty)) {
      final title = notification?.title ?? data['title'] ?? 'New Message';
      final body = notification?.body ?? data['body'] ?? '';

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (body.isNotEmpty)
                Text(
                  body,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.amber,
            onPressed: () => _handleNotificationTap(message),
          ),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final String? type = data['type'];
    final String? matchId = data['match_id'] ?? data['conversation_id'];

    if (kDebugMode) {
      print('Handling Notification Tap: type=$type, matchId=$matchId');
    }

    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    if (type == 'match' && matchId != null && matchId.isNotEmpty) {
      navState.pushNamed('/chat_screen', arguments: {'match_id': matchId});
    } else if (type == 'chat' && matchId != null && matchId.isNotEmpty) {
      navState.pushNamed('/chat_screen', arguments: {'match_id': matchId});
    }
  }

  Future<void> syncFcmToken() async {
    try {
      _fcmToken ??= await _fcm.getToken();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        await _syncTokenToBackend(_fcmToken!);
      }
    } catch (_) {}
  }

  Future<void> onLoginSuccess() async {
    await syncFcmToken();
  }

  Future<void> _syncTokenToBackend(String token) async {
    try {
      final authToken = await StorageManager.instance.getAuthToken();
      if (authToken == null || authToken.trim().isEmpty) {
        if (kDebugMode) {
          print('FCM Token sync skipped: User is not authenticated yet.');
        }
        return;
      }
      await ApiClient.instance.dio.post('/users/fcm-token', data: {'fcm_token': token});
      if (kDebugMode) {
        print('FCM Device Token synced to backend profile.');
      }
    } catch (e) {
      if (kDebugMode) print('FCM sync error: $e');
    }
  }
}
