import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';

/// Screen 4: Protected Chat Room with Anti-Leak Rejection State
/// Spec: URH-UIX-009 Section 3 Screen 4
class ChatRoomScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onUnlockWhatsAppTap;

  const ChatRoomScreen({
    super.key,
    this.lang = 'en',
    this.onUnlockWhatsAppTap,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with SecureScreenMixin {

  final TextEditingController _messageController = TextEditingController();
  bool _hasAntiLeakViolation = true; // Display error state per spec

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: URHeartColors.surfaceRaised,
                  child: Icon(Icons.person, color: URHeartColors.textSecondary, size: 20),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: URHeartColors.statusSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: URHeartColors.canvasBackground, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rahul Verma',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _t('screenshotBlocked'),
                    style: const TextStyle(fontSize: 10.5, color: URHeartColors.brandSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Prominent Gold Button: Unlock WhatsApp 💬
          InkWell(
            onTap: widget.onUnlockWhatsAppTap,
            borderRadius: URHeartTheme.radiusPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: URHeartColors.accentGold.withOpacity(0.18),
                borderRadius: URHeartTheme.radiusPill,
                border: Border.all(color: URHeartColors.accentGold, width: 1.2),
              ),
              child: Text(
                _t('waRevealButton'),
                style: const TextStyle(
                  color: URHeartColors.accentGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: URHeartColors.textPrimary),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'block', child: Text('Block User')),
              const PopupMenuItem(value: 'report', child: Text('Report User')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Bubble Stream
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Match Bubble (Left)
                  _buildBubble(
                    text: 'Hey! Nice to meet you here. How was your day?',
                    timestamp: '08:14 PM',
                    isMe: false,
                  ),
                  const SizedBox(height: 12),

                  // User Bubble (Right)
                  _buildBubble(
                    text: 'Hi Rahul! It was good, just finished work.',
                    timestamp: '08:16 PM',
                    isMe: true,
                    isDelivered: true,
                  ),
                  const SizedBox(height: 12),

                  // ACTIVE ERROR STATE: Rejected User Bubble (Right)
                  if (_hasAntiLeakViolation)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: URHeartColors.statusDanger, size: 20),
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: URHeartColors.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: URHeartColors.statusDanger,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Call me at 9876543210 or check my insta @rahul_01',
                                  style: TextStyle(
                                    color: URHeartColors.textMuted,
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Blocked • 08:17 PM',
                                      style: TextStyle(
                                        color: URHeartColors.statusDanger.withOpacity(0.9),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // High-Alert Bottom Red Banner (Gatekeeper Alert)
            if (_hasAntiLeakViolation)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: URHeartColors.statusDanger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: URHeartColors.statusDanger, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: URHeartColors.statusDanger, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('antiLeakTitle'),
                            style: const TextStyle(
                              color: URHeartColors.statusDanger,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t('antiLeakError'),
                            style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Input Dock
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: URHeartTheme.radiusInput,
                          borderSide: BorderSide(
                            color: _hasAntiLeakViolation ? URHeartColors.statusDanger : URHeartColors.brandSecondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: URHeartTheme.minTouchTarget,
                    height: URHeartTheme.minTouchTarget,
                    decoration: BoxDecoration(
                      color: _hasAntiLeakViolation
                          ? URHeartColors.statusDanger.withOpacity(0.3)
                          : URHeartColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({
    required String text,
    required String timestamp,
    required bool isMe,
    bool isDelivered = false,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? URHeartColors.brandPrimary : URHeartColors.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
                if (isMe && isDelivered) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, color: Colors.white, size: 14),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
