import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../domain/chat_models.dart';
import 'delivery_tick_icon.dart';

/// Sent & received message bubbles with 3-stage delivery ticks (< 160 lines)
class DialogueMessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;
  final bool isDark;

  const DialogueMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final surfaceCard = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;

    final String text = _extractText();
    final DateTime timestamp = _extractTimestamp();
    final MessageDeliveryStatus status = _extractStatus();

    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? pine : surfaceCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(isMe ? 16.0 : 4.0),
            bottomRight: Radius.circular(isMe ? 4.0 : 16.0),
          ),
          border: isMe ? null : Border.all(color: cardBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : primaryText,
                fontSize: 14.0,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : subText,
                    fontSize: 10.0,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4.0),
                  DeliveryTickIcon(
                    status: status,
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

  String _extractText() {
    if (message is ChatMessage) return (message as ChatMessage).text;
    if (message is Map<String, dynamic>) {
      return (message as Map<String, dynamic>)['text'] as String? ?? '';
    }
    return message.toString();
  }

  DateTime _extractTimestamp() {
    if (message is ChatMessage) return (message as ChatMessage).createdAt;
    if (message is Map<String, dynamic>) {
      final raw = (message as Map<String, dynamic>)['timestamp'] ??
          (message as Map<String, dynamic>)['created_at'];
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  MessageDeliveryStatus _extractStatus() {
    if (message is ChatMessage) return (message as ChatMessage).status;
    if (message is Map<String, dynamic>) {
      final s = (message as Map<String, dynamic>)['status'] as String? ?? 'sent';
      switch (s.toLowerCase()) {
        case 'delivered':
          return MessageDeliveryStatus.delivered;
        case 'read':
          return MessageDeliveryStatus.read;
        case 'sent':
        default:
          return MessageDeliveryStatus.sent;
      }
    }
    return MessageDeliveryStatus.sent;
  }
}
