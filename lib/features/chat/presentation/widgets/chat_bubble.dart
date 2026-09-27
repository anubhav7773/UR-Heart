import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/chat_models.dart';
import 'delivery_tick_icon.dart';

/// Mindful 1:1 dialogue message bubble
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    final myBgColor = isDark
        ? DarkSanctuaryTokens.chatBubbleSender
        : LightSanctuaryTokens.chatBubbleSender;
    final peerBgColor = isDark
        ? DarkSanctuaryTokens.chatBubbleReceiver
        : LightSanctuaryTokens.chatBubbleReceiver;
    final peerBorderColor = isDark
        ? DarkSanctuaryTokens.chatBubbleReceiverBorder
        : LightSanctuaryTokens.chatBubbleReceiverBorder;

    const myTextColor = Colors.white;
    final peerTextColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final timestampColor = isMe
        ? (isDark ? DarkSanctuaryTokens.textMuted : const Color(0xFFBAC7C0))
        : (isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4.0,
          bottom: 4.0,
          left: isMe ? 48.0 : 16.0,
          right: isMe ? 16.0 : 48.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? myBgColor : peerBgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18.0),
            topRight: const Radius.circular(18.0),
            bottomLeft: Radius.circular(isMe ? 18.0 : 4.0),
            bottomRight: Radius.circular(isMe ? 4.0 : 18.0),
          ),
          border: isMe ? null : Border.all(color: peerBorderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 4.0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: AppTypography.bodyStandard.copyWith(
                color: isMe ? myTextColor : peerTextColor,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: timestampColor,
                    fontSize: 10.0,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4.0),
                  DeliveryTickIcon(
                    status: message.status,
                    isDark: isDark,
                    size: 13.0,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
