import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      // 1. Request Notification Permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (kDebugMode) {
          print('FCM Notification permission granted.');
        }

        // 2. Fetch FCM Token & Sync to Backend if logged in
        _fcmToken = await _fcm.getToken();
        if (kDebugMode) {
          print('FCM Token: $_fcmToken');
        }
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          await _syncTokenToBackend(_fcmToken!);
        }

        // Token Refresh Listener
        _fcm.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          await _syncTokenToBackend(newToken);
        });

        // 3. Foreground Message Listener (Displays local push banner)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          final data = message.data;
          if (kDebugMode) {
            print('FCM Foreground Message: ${notification?.title} - ${notification?.body} | Data: $data');
          }

          final messenger = _foregroundMessengerKey?.currentState;
          if (messenger != null && (notification != null || data.isNotEmpty)) {
            final title = notification?.title ?? data['title'] ?? 'New Notification';
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
        });

        // 4. Background Notification Tap Handler
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('FCM App Opened from Notification Tap: ${message.data}');
          }
          _handleNotificationTap(message);
        });

        // 5. Terminated App Launch Notification Handler
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          if (kDebugMode) {
            print('FCM Initial Message on Cold Launch: ${initialMessage.data}');
          }
          _handleNotificationTap(initialMessage);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('FCM Service Initialization notice: $e');
      }
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
