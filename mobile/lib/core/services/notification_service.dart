import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';

/// WhatsApp-style Heads-Up Notification Service for In-App Message Alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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
