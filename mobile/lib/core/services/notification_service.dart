import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ur_heart_high_importance',
    'UR-Heart Alerts',
    description: 'Instant notifications for matches and direct chat messages.',
    importance: Importance.max,
    playSound: true,
  );

  /// Configures the High Importance Android Notification Channel so push banners pop down
  /// even when the app is actively open in the foreground.
  Future<void> initialize() async {
    // 1. Request OS Permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notification Channel for Android Foreground Alerts
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Foreground Message Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  /// Registers or syncs device FCM token with backend
  Future<void> registerDeviceToken(String fcmToken) async {
    try {
      final client = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      await client.post(
        '/api/v1/user/device-token',
        data: {'fcm_token': fcmToken},
      );
    } catch (e) {
      debugPrint('NotificationService: Device token sync notice: $e');
    }
  }

  /// Displays an interactive WhatsApp-style heads-up banner notification at the top of the screen
  void showInAppNotification(
    BuildContext context, {
    required String senderName,
    required String messagePreview,
    required String matchId,
    required String senderId,
    String? photoUrl,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -50.0, end: 0.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => entry.remove(),
              child: InkWell(
                onTap: () {
                  entry.remove();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        matchId: matchId,
                        participantName: senderName,
                        participantId: senderId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: URHeartColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: URHeartColors.brandSecondary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: URHeartColors.brandSecondary.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar or Icon
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: URHeartColors.cardSurface,
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: URHeartColors.brandSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: URHeartColors.cardSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'now',
                                    style: TextStyle(
                                      color: URHeartColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              messagePreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: URHeartColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}
