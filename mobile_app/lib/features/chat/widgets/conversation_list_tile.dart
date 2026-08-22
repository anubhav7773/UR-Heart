import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../chat_screen.dart';

class ConversationListTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationListTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String _formatTimestamp(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        return 'now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d';
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String matchName = conversation.partnerName;
    final String avatarUrl = conversation.partnerAvatar;
    final String lastMsg = (conversation.lastMessage != null &&
            conversation.lastMessage!.isNotEmpty)
        ? conversation.lastMessage!
        : 'Matched! Say hello 👋';
    final int unreadCount = conversation.unreadCount;
    final bool lastMsgIsMe = conversation.lastMessageIsMe;
    final String? lastMsgStatus = conversation.lastMessageStatus;
    final String timeLabel = _formatTimestamp(conversation.lastMessageTime);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.surface_interactive,
        highlightColor: AppTheme.surface_interactive.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 52dp Avatar with Verified Badge
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              memCacheWidth: 104,
                              memCacheHeight: 104,
                              placeholder: (_, __) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.text_tertiary,
                                  size: 26,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.surface_interactive,
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.text_tertiary,
                                  size: 26,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.surface_interactive,
                              child: const Icon(
                                Icons.person,
                                color: AppTheme.text_tertiary,
                                size: 26,
                              ),
                            ),
                    ),

                    // Cyber Cerulean Blue Verified Badge
                    if (conversation.isVerified)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppTheme.surface_root,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppTheme.accent_verified_blue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Conversation Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Line: Contact Name & Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            matchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text_primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.text_secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Message Preview Line & Read Receipts / Unread Counter
                    Row(
                      children: [
                        if (lastMsgIsMe && lastMsgStatus != null) ...[
                          Icon(
                            (lastMsgStatus == 'read')
                                ? Icons.done_all_rounded
                                : (lastMsgStatus == 'delivered')
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                            size: 15,
                            color: (lastMsgStatus == 'read')
                                ? AppTheme.accent_verified_blue
                                : AppTheme.text_secondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: unreadCount > 0
                                  ? AppTheme.text_primary
                                  : AppTheme.text_secondary,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent_primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
}
