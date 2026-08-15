import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

class MessageBubbleWidget extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String? mediaUrl;
  final String? mediaType;
  final String? senderAvatarUrl;
  final String status;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    this.mediaUrl,
    this.mediaType,
    this.senderAvatarUrl,
    this.status = 'sent',
    this.isSent = true,
    this.isDelivered = false,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = mediaUrl != null && mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Received Avatar Thumbnail
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[800],
              backgroundImage: (senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(
                      senderAvatarUrl!,
                      maxHeight: 120,
                      maxWidth: 120,
                    )
                  : null,
              child: (senderAvatarUrl == null || senderAvatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 16, color: Colors.white70)
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble Box Container
          Flexible(
            child: Container(
              padding: EdgeInsets.all(hasMedia ? 6.0 : 12.0),
              decoration: BoxDecoration(
                gradient: isMe ? AppTheme.sentBubbleGradient : null,
                color: isMe ? null : AppTheme.receivedBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Optional Media Attachment Image Box
                  if (hasMedia) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl!,
                        width: 220,
                        height: 180,
                        memCacheWidth: 440,
                        memCacheHeight: 360,
                        maxWidthDiskCache: 600,
                        maxHeightDiskCache: 600,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 220,
                          height: 180,
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 220,
                          height: 140,
                          color: Colors.black38,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 32),
                              SizedBox(height: 4),
                              Text('Media unavailable', style: TextStyle(fontSize: 11, color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (message.isNotEmpty) const SizedBox(height: 8),
                  ],

                  // Text Message Content
                  if (message.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hasMedia ? 8.0 : 0.0,
                        vertical: hasMedia ? 4.0 : 0.0,
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Timestamp & Read Receipt Checkmark
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (status == 'read' || isRead) {
      // 3. Double Blue Tick: Read
      return const Icon(
        Icons.done_all,
        size: 15,
        color: Colors.blue,
      );
    } else if (status == 'delivered' || isDelivered) {
      // 2. Double Grey Tick: Delivered to recipient device/socket
      return const Icon(
        Icons.done_all,
        size: 15,
        color: Colors.grey,
      );
    } else if (status == 'sent' || isSent) {
      // 1. Single Grey Tick: Sent to server
      return const Icon(
        Icons.done,
        size: 15,
        color: Colors.grey,
      );
    } else {
      // Sending: Clock indicator
      return const Icon(
        Icons.access_time,
        size: 12,
        color: Colors.grey,
      );
    }
  }
}
