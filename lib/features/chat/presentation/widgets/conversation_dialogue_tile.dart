import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../domain/chat_models.dart';
import '../../../../core/media/sanctuary_image_resolver.dart';
import 'delivery_tick_icon.dart';

/// Conversation dialogue tile for Screen 8 Chats Hub (< 160 lines)
class ConversationDialogueTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool isDark;
  final VoidCallback onTap;

  const ConversationDialogueTile({
    super.key,
    required this.conversation,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final onlineColor = isDark ? DarkSanctuaryTokens.badgeOnline : LightSanctuaryTokens.badgeOnline;
    final isMutual = conversation.categoryTag.toLowerCase().contains('mutual');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(pine, onlineColor),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${conversation.recipientName}, ${conversation.recipientAge}',
                          style: AppTypography.titleH2.copyWith(color: primaryText, fontSize: 15.0),
                        ),
                        Text(
                          _formatTime(conversation.lastMessageTimestamp),
                          style: TextStyle(color: subText, fontSize: 11.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: conversation.isClosed
                                ? (isDark ? Colors.teal.withValues(alpha: 0.2) : Colors.teal.shade50)
                                : isMutual
                                    ? pine.withValues(alpha: 0.15)
                                    : (isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            conversation.isClosed
                                ? 'Past Reflection 🍃'
                                : conversation.categoryTag,
                            style: TextStyle(
                              color: conversation.isClosed
                                  ? (isDark ? Colors.tealAccent : Colors.teal.shade700)
                                  : isMutual
                                      ? pine
                                      : subText,
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (conversation.isStagnant && !conversation.isClosed) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              'Quiet Tide ⏳',
                              style: TextStyle(
                                color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5.0),
                    Row(
                      children: [
                        DeliveryTickIcon(
                          status: conversation.lastMessageStatus,
                          isDark: isDark,
                          size: 14.0,
                        ),
                        const SizedBox(width: 5.0),
                        Expanded(
                          child: Text(
                            conversation.lastMessageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: subText, fontSize: 12.5),
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: pine,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildAvatar(Color pine, Color onlineColor) {
    final imageProvider = resolveSanctuaryImageProvider(conversation.recipientAvatarUrl);
    return Stack(
      children: [
        CircleAvatar(
          radius: 23.0,
          backgroundColor: pine.withValues(alpha: 0.15),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
                  conversation.recipientName.isNotEmpty ? conversation.recipientName[0] : 'S',
                  style: TextStyle(color: pine, fontWeight: FontWeight.bold, fontSize: 16.0),
                )
              : null,
        ),
        if (conversation.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11.0,
              height: 11.0,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background,
                  width: 1.8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
