import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
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

        // 2. Fetch FCM Token & Sync to Backend
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

        // 3. Foreground Message Listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('FCM Foreground Message: ${message.notification?.title} - ${message.notification?.body}');
          }
        });

        // 4. Set Background Message Handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FCM Service Initialization notice: $e');
      }
    }
  }

  Future<void> _syncTokenToBackend(String token) async {
    try {
      await ApiClient.instance.putProfile({'fcm_token': token});
      if (kDebugMode) {
        print('FCM Device Token synced to backend profile.');
      }
    } catch (e) {
      // Background token sync fallback
    }
  }
}
