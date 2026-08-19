import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_launcher.dart';

class MessageBubbleWidget extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String? mediaUrl;
  final String? mediaType;
  final String messageType;
  final Map<String, dynamic>? metadata;
  final String? senderAvatarUrl;
  final String status;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;
  final bool isDeleted;
  final VoidCallback? onLongPress;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    this.mediaUrl,
    this.mediaType,
    this.messageType = 'text',
    this.metadata,
    this.senderAvatarUrl,
    this.status = 'sent',
    this.isSent = true,
    this.isDelivered = false,
    this.isRead = false,
    this.isDeleted = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMeetupSpot = !isDeleted && (messageType == 'meetup_spot' || mediaType == 'meetup_spot');
    final bool hasMedia = !isDeleted && mediaUrl != null && mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
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

          // Bubble Box / Meetup Spot Card
          Flexible(
            child: GestureDetector(
              onLongPress: (!isDeleted && isMe) ? onLongPress : null,
              child: isMeetupSpot
                  ? _buildMeetupSpotCard(context)
                  : Container(
                      padding: EdgeInsets.all(hasMedia ? 6.0 : 12.0),
                      decoration: BoxDecoration(
                        gradient: (isMe && !isDeleted) ? AppTheme.sentBubbleGradient : null,
                        color: isDeleted
                            ? AppTheme.surfaceColor.withValues(alpha: 0.5)
                            : (isMe ? null : AppTheme.receivedBubbleColor),
                        border: isDeleted
                            ? Border.all(color: AppTheme.cardBorderColor.withValues(alpha: 0.5), width: 1)
                            : (isMe ? null : Border.all(color: AppTheme.receivedBubbleBorderColor, width: 1)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                        boxShadow: isDeleted
                            ? null
                            : const [
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
                          // Deleted Placeholder State
                          if (isDeleted)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block_flipped,
                                    size: 13,
                                    color: AppTheme.mutedTextColor.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isMe ? 'You unsent a message' : 'This message was unsent',
                                    style: TextStyle(
                                      color: AppTheme.mutedTextColor.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
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
                                    color: isMe ? Colors.white70 : AppTheme.mutedTextColor,
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
                        ],
                      ),
                    ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Native Interactive Meetup Spot Bubble Card
  Widget _buildMeetupSpotCard(BuildContext context) {
    final meta = metadata ?? {};
    final String name = (meta['name'] ?? 'Meetup Spot').toString();
    final String category = (meta['category'] ?? 'Cafe & Lounge').toString();
    final String address = (meta['address'] ?? '').toString();
    final double distanceKm = (meta['distance_km'] as num?)?.toDouble() ?? 0.0;
    final double lat = (meta['latitude'] as num?)?.toDouble() ?? 0.0;
    final double lon = (meta['longitude'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF171822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF3366).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge + Distance Tag
          Row(
            children: [
              const Icon(Icons.place_rounded, color: Color(0xFFFF3366), size: 16),
              const SizedBox(width: 6),
              const Text(
                'MEETUP SPOT',
                style: TextStyle(
                  color: Color(0xFFFF3366),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Spot Name
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // Category & Street
          Text(
            address.isNotEmpty ? '$category • $address' : category,
            style: const TextStyle(
              color: Color(0xFF8E8EA0),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Direct Action Button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                MapLauncher.openExactLocation(
                  latitude: lat,
                  longitude: lon,
                  placeName: name,
                );
              },
              icon: const Icon(Icons.directions_outlined, size: 16),
              label: const Text(
                'Open in Google Maps',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Timestamp & Read Receipt Checkmark
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: isMe ? Colors.white70 : AppTheme.mutedTextColor,
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
    );
  }

  /// ABSOLUTE 3-State WhatsApp Tick Logic for Outbound Messages:
  /// - INCOMING MESSAGES: NO TICKS
  /// - OUTGOING MESSAGES ONLY:
  ///   1. Read (Double Blue Tick): `isRead == true` OR `status == 'read'`
  ///   2. Delivered (Double Grey Tick): `status == 'delivered'` OR `isDelivered == true`
  ///   3. Sent (Single Grey Tick): `status == 'sent'` OR `isSent == true`
  ///   4. Sending (Clock): Default pending state
  Widget _buildStatusIcon() {
    if (!isMe) return const SizedBox.shrink();

    // State 1: READ - Double Blue Tick
    if (isRead == true || status.toLowerCase() == 'read') {
      return const Icon(
        Icons.done_all,
        size: 16,
        color: AppTheme.verifiedBlue,
      );
    }

    // State 2: DELIVERED - Double Grey Tick
    if (status.toLowerCase() == 'delivered' || (isDelivered == true && !isRead)) {
      return Icon(
        Icons.done_all,
        size: 16,
        color: Colors.grey.shade600,
      );
    }

    // State 3: SENT - Single Grey Tick
    if (status.toLowerCase() == 'sent' || (isSent == true && !isDelivered)) {
      return Icon(
        Icons.done,
        size: 16,
        color: Colors.grey.shade600,
      );
    }

    // State 4: SENDING - Clock Icon (Optimistic/Pending)
    return Icon(
      Icons.access_time,
      size: 14,
      color: Colors.grey.shade400,
    );
  }
}
