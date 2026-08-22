import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/services/security_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../subscription/subscription_sheet.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'widgets/safe_bridge_paywall_sheet.dart';
import 'widgets/meetup_spots_sheet.dart';
import 'widgets/meetup_actions_sheet.dart';

class ChatMessage {
  final String id;
  final String? clientMsgId;
  final String senderId;
  final String text;
  final String? mediaUrl;
  final bool isViewOnce;
  final DateTime timestamp;
  final String status;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;
  final bool isDeleted;
  final String messageType;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    this.clientMsgId,
    required this.senderId,
    required this.text,
    this.mediaUrl,
    this.isViewOnce = false,
    required this.timestamp,
    this.status = 'sent',
    this.isSent = true,
    this.isDelivered = false,
    this.isRead = false,
    this.isDeleted = false,
    this.messageType = 'text',
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final String rawStatus =
        (json['status'] ?? 'sent').toString().toLowerCase();
    final bool isRead = json['is_read'] == true || rawStatus == 'read';
    final bool isDelivered =
        json['is_delivered'] == true || rawStatus == 'delivered' || isRead;
    final bool isDeleted = json['is_deleted'] == true;

    DateTime parsedTime;
    try {
      final rawTime = json['created_at'] ?? json['timestamp'];
      parsedTime = rawTime != null
          ? DateTime.parse(rawTime.toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedTime = DateTime.now();
    }

    final rawMeta = json['metadata'] ?? json['extra_metadata'];
    final Map<String, dynamic>? parsedMeta =
        rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null;

    return ChatMessage(
      id: (json['id'] ?? json['message_id'] ?? '').toString(),
      clientMsgId: json['client_msg_id']?.toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      text: isDeleted
          ? ''
          : (json['content'] ?? json['text'] ?? json['message'] ?? '').toString(),
      mediaUrl: isDeleted ? null : json['media_url']?.toString(),
      isViewOnce: json['is_view_once'] == true,
      timestamp: parsedTime,
      status: isRead
          ? 'read'
          : (isDelivered
              ? 'delivered'
              : (rawStatus.isNotEmpty ? rawStatus : 'sent')),
      isSent: true,
      isDelivered: isDelivered,
      isRead: isRead,
      isDeleted: isDeleted,
      messageType: (json['message_type'] ?? json['media_type'] ?? 'text').toString(),
      metadata: parsedMeta,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? clientMsgId,
    String? senderId,
    String? text,
    String? mediaUrl,
    bool? isViewOnce,
    DateTime? timestamp,
    String? status,
    bool? isSent,
    bool? isDelivered,
    bool? isRead,
    bool? isDeleted,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isSent: isSent ?? this.isSent,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// A parsed conversation item representing a match thread.
class Conversation {
  final String id;
  final String matchId;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String? lastMessage;
  final String? lastMessageTime;
  final String? lastMessageStatus;
  final bool lastMessageIsMe;
  final int unreadCount;
  final bool isOnline;
  final bool isVerified;
  final DateTime? lastActiveAt;
  final double? latitude;
  final double? longitude;

  const Conversation({
    required this.id,
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageStatus,
    this.lastMessageIsMe = false,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isVerified = false,
    this.lastActiveAt,
    this.latitude,
    this.longitude,
  });

  /// A match is considered an active conversation if messages have been exchanged.
  bool get hasMessages =>
      lastMessage != null &&
      lastMessage!.trim().isNotEmpty &&
      lastMessageTime != null &&
      lastMessageTime!.trim().isNotEmpty &&
      lastMessage != 'Matched! Say hello 👋';

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // 1. Resolve ID / Match ID
    final String convId =
        (json['id'] ?? json['conversation_id'] ?? json['match_id'] ?? '')
            .toString();
    final String mId =
        (json['match_id'] ?? json['id'] ?? json['conversation_id'] ?? '')
            .toString();

    // 2. Resolve Partner ID
    final String pId = (json['partner']?['id'] ??
            json['partner']?['user_id'] ??
            json['partner_id'] ??
            json['target_user_id'] ??
            json['target_id'] ??
            json['user_id'] ??
            '')
        .toString();

    // 3. Resolve Partner Name
    final String pName = (json['partner']?['name'] ??
            json['partner']?['full_name'] ??
            json['user']?['name'] ??
            json['user']?['full_name'] ??
            json['partner_name'] ??
            json['matched_user_name'] ??
            json['target_user_name'] ??
            json['full_name'] ??
            json['match_name'] ??
            'User')
        .toString();

    // 4. Resolve Partner Avatar
    dynamic rawPhotos = json['partner']?['photos'] ?? json['photos'];
    String firstPhoto = '';
    if (rawPhotos is List && rawPhotos.isNotEmpty) {
      firstPhoto = (rawPhotos[0] is Map
              ? (rawPhotos[0]['photo_url'] ?? rawPhotos[0]['url'])
              : rawPhotos[0])
          .toString();
    }
    final String pAvatar = (json['partner']?['avatar_url'] ??
            json['partner']?['photo_url'] ??
            json['partner_avatar'] ??
            json['matched_user_avatar'] ??
            json['target_user_photo'] ??
            json['avatar_url'] ??
            json['avatar'] ??
            json['photo_url'] ??
            firstPhoto)
        .toString();

    // 5. Resolve Last Message
    String? lastMsg;
    if (json['last_message'] != null) {
      if (json['last_message'] is Map) {
        lastMsg = (json['last_message']['message'] ??
                json['last_message']['content'] ??
                json['last_message']['text'])
            ?.toString();
      } else {
        final str = json['last_message'].toString().trim();
        if (str.isNotEmpty) {
          lastMsg = str;
        }
      }
    }

    // 6. Resolve Unread Count
    int unread = 0;
    if (json['unread_count'] is int) {
      unread = json['unread_count'] as int;
    } else if (json['unread_count'] != null) {
      unread = int.tryParse(json['unread_count'].toString()) ?? 0;
    }

    // 7. Presence & Timestamps
    DateTime? lastActive;
    final lastSeenStr = json['last_active_at'] ??
        json['last_seen'] ??
        json['matched_user_last_active'] ??
        json['partner']?['last_seen'];
    if (lastSeenStr != null) {
      try {
        lastActive = DateTime.parse(lastSeenStr.toString()).toLocal();
      } catch (_) {}
    }

    final bool online = json['is_online'] == true ||
        json['matched_user_is_online'] == true ||
        json['partner']?['is_online'] == true;

    final bool verified = json['is_verified'] == true ||
        json['matched_user_is_verified'] == true ||
        json['is_verified_local'] == true ||
        json['partner']?['is_verified'] == true;

    final String? lastMsgTime = (json['last_message_time'] ??
            json['last_message_at'] ??
            json['updated_at'])
        ?.toString();
    final String? lastMsgStatus = (json['last_message_status'] ??
            (json['last_message'] is Map
                ? json['last_message']['status']
                : null))
        ?.toString();
    final bool lastMsgIsMe = json['last_message_is_me'] == true ||
        (json['last_message'] is Map && json['last_message']['is_me'] == true);

    final double? pLat = (json['partner']?['latitude'] ??
            json['partner']?['lat'] ??
            json['latitude'] ??
            json['lat'] as num?)
        ?.toDouble();
    final double? pLon = (json['partner']?['longitude'] ??
            json['partner']?['lon'] ??
            json['longitude'] ??
            json['lon'] as num?)
        ?.toDouble();

    return Conversation(
      id: convId,
      matchId: mId,
      partnerId: pId,
      partnerName: pName.isNotEmpty ? pName : 'User',
      partnerAvatar: pAvatar,
      lastMessage: lastMsg,
      lastMessageTime: lastMsgTime,
      lastMessageStatus: lastMsgStatus,
      lastMessageIsMe: lastMsgIsMe,
      unreadCount: unread,
      isOnline: online,
      isVerified: verified,
      lastActiveAt: lastActive,
      latitude: pLat,
      longitude: pLon,
    );
  }

  ChatRecipient toRecipient() {
    return ChatRecipient(
      id: partnerId.isNotEmpty ? partnerId : matchId,
      name: partnerName,
      avatarUrl: partnerAvatar,
      isVerified: isVerified,
      isOnline: isOnline,
      lastActiveAt: lastActiveAt,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// The person on the other side of a chat.
class ChatRecipient {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final double? latitude;
  final double? longitude;

  const ChatRecipient({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.isVerified = false,
    this.isOnline = false,
    this.lastActiveAt,
    this.latitude,
    this.longitude,
  });

  factory ChatRecipient.fromConversation(Map<String, dynamic> conversation) {
    return Conversation.fromJson(conversation).toRecipient();
  }

  ChatRecipient copyWith({
    String? name,
    String? avatarUrl,
    bool? isVerified,
    bool? isOnline,
    DateTime? lastActiveAt,
    double? latitude,
    double? longitude,
  }) {
    return ChatRecipient(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

String formatRelativePresence(bool isOnline, DateTime? lastActive) {
  if (isOnline) return 'Online';
  if (lastActive == null) return 'Offline';

  final diff = DateTime.now().difference(lastActive);
  if (diff.inSeconds < 180) {
    return 'Online';
  } else if (diff.inMinutes < 60) {
    final mins = diff.inMinutes;
    return 'Active ${mins <= 1 ? 1 : mins}m ago';
  } else if (diff.inHours < 24) {
    final hours = diff.inHours;
    return 'Active ${hours}h ago';
  } else if (diff.inDays == 1) {
    return 'Active yesterday';
  } else if (diff.inDays < 7) {
    return 'Active ${diff.inDays}d ago';
  } else {
    return 'Active recently';
  }
}

class _RecipientHeaderLoadingPlaceholder extends StatelessWidget {
  const _RecipientHeaderLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
        const SizedBox(width: 10),
        Container(
          width: 96,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}

typedef ChatsScreen = ConversationsScreen;

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  List<Conversation> _conversations = [];

  List<Conversation> get _newMatches =>
      _conversations.where((c) => !c.hasMessages).toList();

  List<Conversation> get _activeConversations =>
      _conversations.where((c) => c.hasMessages).toList();

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    try {
      final response = await ApiClient.instance.getChatConversations();
      debugPrint('Conversations raw type: ${response.data.runtimeType}');
      debugPrint('Conversations JSON: ${response.data}');

      List<Conversation> parsedList = [];
      if (response.data != null) {
        // Handle response.data being a raw JSON string (Dio may not auto-decode)
        dynamic rawData = response.data;
        if (rawData is String) {
          try {
            rawData = jsonDecode(rawData);
          } catch (decodeErr) {
            debugPrint('[ConversationsScreen] jsonDecode failed: $decodeErr');
          }
        }

        List<dynamic> rawList = [];
        if (rawData is List) {
          rawList = rawData;
        } else if (rawData is Map) {
          if (rawData['data'] is List) {
            rawList = rawData['data'] as List<dynamic>;
          } else if (rawData['conversations'] is List) {
            rawList = rawData['conversations'] as List<dynamic>;
          } else if (rawData['matches'] is List) {
            rawList = rawData['matches'] as List<dynamic>;
          } else if (rawData['results'] is List) {
            rawList = rawData['results'] as List<dynamic>;
          }
        }

        debugPrint(
            '[ConversationsScreen] Parsed ${rawList.length} conversation items from response');

        for (final item in rawList) {
          if (item is Map) {
            try {
              parsedList
                  .add(Conversation.fromJson(Map<String, dynamic>.from(item)));
            } catch (err) {
              debugPrint('Error parsing conversation item: $err — raw: $item');
            }
          }
        }
      }

      debugPrint(
          '[ConversationsScreen] Final parsed conversations count: ${parsedList.length}');

      if (mounted) {
        setState(() {
          _conversations = parsedList;
          _hasError = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ConversationsScreen] Error loading conversations: $e');
      if (e is DioException) {
        debugPrint(
            '[ConversationsScreen] StatusCode: ${e.response?.statusCode}, Response: ${e.response?.data}');
      }
      if (mounted) {
        setState(() {
          _hasError = _conversations.isEmpty;
          _errorMessage =
              'Unable to load matches. Please check your connection.';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _openChat(Conversation conv) async {
    final recipientUser = conv.toRecipient();
    final String matchId = conv.matchId.isNotEmpty ? conv.matchId : conv.id;
    if (recipientUser.id.isEmpty && matchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This conversation has no recipient. Please refresh and try again.')),
      );
      return;
    }
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          matchId: matchId,
          recipientUser: recipientUser,
        ),
      ),
    );
    if (res == true || res == null) {
      _fetchConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newMatches = _newMatches;
    final activeConvs = _activeConversations;
    final bool isEmpty = newMatches.isEmpty && activeConvs.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: const Text('Matches & Conversations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Conversations',
            onPressed: () => _fetchConversations(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchConversations(forceRefresh: true),
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceColor,
        child: _isLoading && _conversations.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _hasError && _conversations.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.cloud_off_rounded,
                                size: 64, color: Colors.redAccent),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Connection Issue',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? 'Unable to load conversations.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _fetchConversations(forceRefresh: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.favorite_outline,
                                    size: 64, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'No matches yet!',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Keep swiping on the feed or send a Direct DM to start chatting.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          // 1. New Matches Horizontal Section
                          if (newMatches.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                              child: Row(
                                children: [
                                  const Text(
                                    'New Matches',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '${newMatches.length}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 104,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: newMatches.length,
                                itemBuilder: (context, index) {
                                  final match = newMatches[index];
                                  final firstName =
                                      match.partnerName.split(' ').first;
                                  return GestureDetector(
                                    onTap: () => _openChat(match),
                                    child: Container(
                                      width: 76,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(2.5),
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFFE91E63),
                                                      Color(0xFFFF5252),
                                                      Color(0xFFFF9800),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 28,
                                                  backgroundColor:
                                                      Colors.grey[900],
                                                  backgroundImage: match
                                                          .partnerAvatar
                                                          .isNotEmpty
                                                      ? CachedNetworkImageProvider(
                                                          match.partnerAvatar)
                                                      : null,
                                                  child: match.partnerAvatar
                                                          .isEmpty
                                                      ? const Icon(Icons.person,
                                                          color: Colors.white70,
                                                          size: 28)
                                                      : null,
                                                ),
                                              ),
                                              if (match.isOnline)
                                                Positioned(
                                                  right: 2,
                                                  bottom: 2,
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: Colors.greenAccent,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: AppTheme
                                                            .backgroundColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (match.unreadCount > 0)
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          AppTheme.primaryColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      '${match.unreadCount}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  firstName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (match.isVerified) ...[
                                                const SizedBox(width: 2),
                                                const Icon(Icons.verified,
                                                    size: 12,
                                                    color: AppTheme.verifiedBlue),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(
                                color: AppTheme.cardBorderColor,
                                height: 16,
                                indent: 16,
                                endIndent: 16),
                          ],

                          // 2. Active Conversations Header
                          if (newMatches.isNotEmpty || activeConvs.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                              child: Text(
                                'Conversations',
                                style: TextStyle(
                                  color: AppTheme.mutedTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                          // 3. Prompt if no active conversations yet
                          if (activeConvs.isEmpty && newMatches.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 36),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        size: 36, color: AppTheme.mutedTextColor),
                                    SizedBox(height: 12),
                                    Text(
                                      'Tap a match above to send your first message',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.mutedTextColor,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // 4. Vertical Active Conversations List
                          ...activeConvs.map((conv) {
                            final String matchName = conv.partnerName;
                            final String avatarUrl = conv.partnerAvatar;
                            final String lastMsg = (conv.lastMessage != null &&
                                    conv.lastMessage!.isNotEmpty)
                                ? conv.lastMessage!
                                : 'Matched! Say hello';
                            final int unreadCount = conv.unreadCount;
                            final bool isOnline = conv.isOnline;
                            final bool lastMsgIsMe = conv.lastMessageIsMe;
                            final String? lastMsgStatus =
                                conv.lastMessageStatus;

                            // Parse last_message_time for relative display
                            String timeLabel = '';
                            if (conv.lastMessageTime != null &&
                                conv.lastMessageTime!.isNotEmpty) {
                              try {
                                final dt =
                                    DateTime.parse(conv.lastMessageTime!)
                                        .toLocal();
                                final now = DateTime.now();
                                final diff = now.difference(dt);
                                if (diff.inMinutes < 1) {
                                  timeLabel = 'now';
                                } else if (diff.inMinutes < 60) {
                                  timeLabel = '${diff.inMinutes}m';
                                } else if (diff.inHours < 24) {
                                  timeLabel = '${diff.inHours}h';
                                } else if (diff.inDays == 1) {
                                  timeLabel = 'Yesterday';
                                } else if (diff.inDays < 7) {
                                  timeLabel = '${diff.inDays}d';
                                } else {
                                  timeLabel = '${dt.day}/${dt.month}';
                                }
                              } catch (_) {}
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              onTap: () => _openChat(conv),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.surfaceColor,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            avatarUrl,
                                            maxHeight: 120,
                                            maxWidth: 120,
                                          )
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? const Icon(Icons.person,
                                            color: AppTheme.mutedTextColor)
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? Colors.greenAccent
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.backgroundColor,
                                            width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      matchName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  if (conv.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified,
                                        size: 14, color: AppTheme.verifiedBlue),
                                  ],
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  if (lastMsgIsMe &&
                                      lastMsgStatus != null) ...[
                                    Icon(
                                      (lastMsgStatus == 'read')
                                          ? Icons.done_all
                                          : (lastMsgStatus == 'delivered')
                                              ? Icons.done_all
                                              : Icons.done,
                                      size: 14,
                                      color: (lastMsgStatus == 'read')
                                          ? AppTheme.verifiedBlue
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Expanded(
                                    child: Text(
                                      lastMsg,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: unreadCount > 0
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: unreadCount > 0
                                            ? AppTheme.primaryColor
                                            : AppTheme.mutedTextColor,
                                      ),
                                    ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String matchId;
  final ChatRecipient recipientUser;
  final bool isDirectDM;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.recipientUser,
    this.isDirectDM = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isPremiumUser = false;
  final bool _isTyping = false;
  Timer? _inChatAdTimer;
  int _secondsActive = 0;

  // Safe WhatsApp & Location Bridge State
  int _mutualMessageCount = 0;
  bool _myWhatsAppConsent = false;
  bool _partnerWhatsAppConsent = false;
  bool _isWhatsAppUnlocked = false;
  String? _unlockedPhoneNumber;

  bool _myLocationConsent = false;
  bool _partnerLocationConsent = false;
  bool _isLocationUnlocked = false;
  String? _partnerMapsUrl;

  bool _myBridgePaid = false;
  bool _partnerBridgePaid = false;

  // Mutual Meetup Consent & Local Date Spot Radar State
  bool _myMeetupConsent = false;
  bool _partnerMeetupConsent = false;
  bool _isMeetupUnlocked = false;

  final List<ChatMessage> _messages = [];
  final Set<String> _processedMessageIds = {};
  Timer? _realtimePollingTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  int _wsReconnectAttempts = 0;
  Timer? _wsReconnectTimer;
  bool _isConnectingWs = false;
  bool _isDisposed = false;

  ChatRecipient? _recipientProfile;
  bool _isRecipientProfileLoading = true;
  String _recipientDistanceLabel = 'Location pending';

  ChatRecipient get _displayRecipient =>
      _recipientProfile ?? widget.recipientUser;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _initChat();
    // Refresh the local GPS fix before calculating the recipient distance.
    LocationService.instance.getCurrentLocation().then((position) {
      if (position == null &&
          mounted &&
          _recipientDistanceLabel == 'Location pending') {
        setState(() => _recipientDistanceLabel = 'Location unavailable');
      }
    });
    _fetchConsentStatus();
    _fetchRecipientProfile();
  }

  Future<void> _initChat() async {
    await _loadUserStatus();
    if (mounted) {
      _startRealtimeStreamListener();
      await _fetchMessages();
      // Immediately mark incoming messages as read when opening chat
      _emitReadReceipt();
    }
  }

  Future<void> _enableScreenshotProtection() async {
    await WindowSecurityService.syncFromStorage();
  }

  Future<void> _fetchRecipientProfile() async {
    try {
      final recipientId = widget.recipientUser.id;
      if (recipientId.isNotEmpty) {
        final response = await ApiClient.instance.dio.get(
          '/profile',
          queryParameters: {'user_id': recipientId},
        );
        if (response.data != null && response.data['data'] != null) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(response.data['data'] as Map);
          final returnedUserId =
              (data['user_id'] ?? data['id'] ?? '').toString();

          // A profile endpoint response for another account must identify that
          // account. Never let a response for the signed-in user overwrite the
          // recipient state, even if an older backend ignores `user_id`.
          if (returnedUserId != recipientId) return;

          if (mounted) {
            setState(() {
              final String name = (data['full_name'] ?? '').toString();
              String avatarUrl = widget.recipientUser.avatarUrl;
              final photos = data['photos'] as List<dynamic>?;
              if (photos != null && photos.isNotEmpty) {
                avatarUrl = photos.first.toString();
              }
              DateTime? lastActive;
              final lastSeenStr = data['last_active_at'] ?? data['last_seen'];
              if (lastSeenStr != null) {
                try {
                  lastActive = DateTime.parse(lastSeenStr.toString()).toLocal();
                } catch (_) {}
              }
              final bool isOnline = data['is_online'] == true;

              _recipientProfile = widget.recipientUser.copyWith(
                name: name.isNotEmpty ? name : widget.recipientUser.name,
                avatarUrl: avatarUrl,
                isVerified:
                    data['is_verified'] ?? data['is_verified_local'] ?? false,
                isOnline: isOnline,
                lastActiveAt: lastActive,
              );

              final myPos = LocationService.instance.currentPosition;
              final double? rLat = (data['latitude'] as num?)?.toDouble();
              final double? rLng = (data['longitude'] as num?)?.toDouble();

              if (myPos != null && rLat != null && rLng != null) {
                final distKm = ChatProvider.calculateHaversineDistance(
                  lat1: myPos.latitude,
                  lon1: myPos.longitude,
                  lat2: rLat,
                  lon2: rLng,
                );
                _recipientDistanceLabel =
                    ChatProvider.getFormattedDistanceLabel(distKm);
              } else if (data['area_name'] != null) {
                _recipientDistanceLabel = data['area_name'].toString();
              }
            });
          }
        }
      }
    } catch (_) {
      // Keep the explicitly supplied recipient visible; never substitute self.
    } finally {
      if (mounted) setState(() => _isRecipientProfileLoading = false);
    }
  }

  void _startRealtimeStreamListener() {
    _connectWebSocket();
    _realtimePollingTimer?.cancel();
    // Watchdog timer (every 10s) in case WebSocket connection drops
    _realtimePollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isDisposed) {
        _fetchMessages(silent: true);
        _fetchConsentStatus();
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed || _isConnectingWs || widget.matchId.isEmpty) return;
    _isConnectingWs = true;
    _wsReconnectTimer?.cancel();

    try {
      _wsSubscription?.cancel();
      _wsSubscription = null;
      try {
        _wsChannel?.sink.close();
      } catch (_) {}
      _wsChannel = null;

      final token = await StorageManager.instance.getAuthToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) print('[WS] No active session token found');
        _isConnectingWs = false;
        return;
      }

      String baseWsUrl = ApiClient.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceAll(':0', '');

      final wsUri = Uri.parse('$baseWsUrl/chat/ws/${widget.matchId}?token=${Uri.encodeComponent(token)}');

      final rawSocket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 6));

      if (_isDisposed || !mounted) {
        rawSocket.close();
        return;
      }

      _wsChannel = IOWebSocketChannel(rawSocket);
      _wsSubscription = _wsChannel?.stream.listen(
        (rawData) {
          if (!_isDisposed && mounted) {
            _wsReconnectAttempts = 0;
            try {
              _handleIncomingWebSocketData(rawData);
            } catch (e) {
              if (kDebugMode) print('[WS] Handled data error: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) print('[WS] Handled stream error: $error');
          _scheduleWsReconnect();
        },
        onDone: () {
          if (kDebugMode) print('[WS] Connection closed cleanly.');
          _scheduleWsReconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (kDebugMode) print('[WS] Handled connection failure silently: $error');
      _scheduleWsReconnect();
    } finally {
      _isConnectingWs = false;
    }
  }

  void _scheduleWsReconnect() {
    if (_isDisposed || !mounted) return;
    _wsReconnectTimer?.cancel();

    final delaySeconds = math.min(2 * math.pow(2, _wsReconnectAttempts).toInt(), 16);
    _wsReconnectAttempts++;

    if (kDebugMode) {
      print('[Chat WS] Scheduling reconnect in ${delaySeconds}s (attempt $_wsReconnectAttempts)');
    }

    _wsReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && mounted) {
        _connectWebSocket();
      }
    });
  }

  void _handleIncomingWebSocketData(dynamic rawData) {
    try {
      Map<String, dynamic> data;
      if (rawData is String) {
        data = jsonDecode(rawData);
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else {
        return;
      }

      final String type = (data['type'] ?? 'message').toString();

      if (type == 'error' || data['code'] == 'CONTENT_FILTER_BLOCKED') {
        final errorMsg = data['message'] ??
            '⚠️ Contact details, usernames, ya location share karna mana hai. 15 messages ke baad Safe Bridge unlock karein!';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMsg.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (type == 'MESSAGE_UNSENT') {
        if (mounted) {
          final msgId = (data['message_id'] ?? '').toString();
          if (msgId.isNotEmpty) {
            setState(() {
              final idx = _messages.indexWhere(
                  (m) => m.id == msgId || m.clientMsgId == msgId);
              if (idx != -1) {
                _messages[idx] =
                    _messages[idx].copyWith(isDeleted: true, text: '');
              }
            });
          }
        }
        return;
      }

      if (type == 'MEETUP_CONSENT_UPDATED') {
        if (mounted) {
          setState(() {
            final senderId = (data['sender_id'] ?? '').toString();
            final bool isSenderMe = (_currentUserId.isNotEmpty && senderId == _currentUserId);
            final user1Agreed = data['user1_meetup_agreed'] == true;
            final user2Agreed = data['user2_meetup_agreed'] == true;
            _isMeetupUnlocked = data['is_meetup_unlocked'] == true;

            if (data['my_meetup_consent'] != null) {
              _myMeetupConsent = data['my_meetup_consent'] == true;
            } else if (isSenderMe) {
              _myMeetupConsent = user1Agreed || user2Agreed;
            }
            if (data['partner_meetup_consent'] != null) {
              _partnerMeetupConsent = data['partner_meetup_consent'] == true;
            } else if (!isSenderMe) {
              _partnerMeetupConsent = user1Agreed || user2Agreed;
            }
          });
        }
        return;
      }

      if (type == 'consent_update' || type == 'bridge_payment_update') {
        if (mounted) {
          setState(() {
            if (data['total_messages'] != null) {
              _mutualMessageCount = data['total_messages'];
            }
            _isWhatsAppUnlocked = data['whatsapp_unlocked'] ??
                (data['is_fully_unlocked'] ?? _isWhatsAppUnlocked);
            _isLocationUnlocked = data['location_unlocked'] ??
                (data['is_fully_unlocked'] ?? _isLocationUnlocked);
            if (data['my_whatsapp_consent'] != null) {
              _myWhatsAppConsent = data['my_whatsapp_consent'];
            }
            if (data['my_location_consent'] != null) {
              _myLocationConsent = data['my_location_consent'];
            }
            if (data['partner_whatsapp_consent'] != null) {
              _partnerWhatsAppConsent = data['partner_whatsapp_consent'];
            }
            if (data['partner_location_consent'] != null) {
              _partnerLocationConsent = data['partner_location_consent'];
            }
            if (data['my_meetup_consent'] != null) {
              _myMeetupConsent = data['my_meetup_consent'];
            }
            if (data['partner_meetup_consent'] != null) {
              _partnerMeetupConsent = data['partner_meetup_consent'];
            }
            if (data['is_meetup_unlocked'] != null) {
              _isMeetupUnlocked = data['is_meetup_unlocked'];
            }
            if (data['my_payment_done'] != null) {
              _myBridgePaid = data['my_payment_done'];
            }
            if (data['partner_payment_done'] != null) {
              _partnerBridgePaid = data['partner_payment_done'];
            }
            if (data['partner_phone'] != null) {
              _unlockedPhoneNumber = data['partner_phone'];
            }
            if (data['partner_maps_url'] != null) {
              _partnerMapsUrl = data['partner_maps_url'];
            }
          });
        }
      } else if (type == 'messages_read' || type == 'read_receipt') {
        if (mounted) {
          setState(() {
            for (int i = 0; i < _messages.length; i++) {
              final msg = _messages[i];
              final isMe = (_currentUserId.isNotEmpty &&
                      msg.senderId == _currentUserId) ||
                  msg.senderId == 'current_user_id';
              if (isMe) {
                _messages[i] = msg.copyWith(
                  status: 'read',
                  isSent: true,
                  isDelivered: true,
                  isRead: true,
                );
              }
            }
          });
        }
      } else if (type == 'message' ||
          data.containsKey('content') ||
          data.containsKey('id')) {
        bool changed = false;
        if (mounted) {
          setState(() {
            changed = _upsertServerMessage(data);
          });
          if (changed) {
            _scrollToBottom();
            final senderId = (data['sender_id'] ?? '').toString();
            if (senderId.isNotEmpty &&
                senderId != _currentUserId &&
                senderId != 'current_user_id') {
              _emitReadReceipt();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Chat WS Parse Error] $e');
    }
  }

  void _emitReadReceipt() {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'read_receipt',
        'match_id': widget.matchId,
        'reader_id': _currentUserId,
      }));
      ApiClient.instance.markMessagesAsRead(widget.matchId).then((res) {
        // POST /chat/{matchId}/read tells the server WE have read the partner's
        // messages. Our own sent messages' read status is updated when the
        // PARTNER reads them, arriving via WebSocket 'messages_read' event
        // (handled in _handleIncomingWebSocketData).
        if (kDebugMode && mounted) {
          debugPrint('[Chat] markMessagesAsRead response: ${res.statusCode}');
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    try {
      final response = await ApiClient.instance.getMessages(widget.matchId);
      // Handle response.data being a raw JSON string
      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (_) {}
      }
      if (responseData != null &&
          responseData is Map &&
          responseData['data'] != null) {
        final List<dynamic> rawMsgs =
            responseData['data'] is List ? responseData['data'] : [];

        bool changed = false;
        setState(() {
          for (final item in rawMsgs) {
            if (item is Map) {
              changed = _upsertServerMessage(Map<String, dynamic>.from(item)) ||
                  changed;
            }
          }
        });
        if (changed || (!silent && _messages.isNotEmpty)) {
          _scrollToBottom();
        }

        _emitReadReceipt();
      }
    } catch (_) {}
  }

  /// Adds a server message once, or swaps an optimistic client message in place.
  bool _upsertServerMessage(Map<String, dynamic> data) {
    final serverMessage = ChatMessage.fromJson(data);
    final dbId = serverMessage.id;
    final clientMsgId = serverMessage.clientMsgId ?? '';
    if (dbId.isEmpty && clientMsgId.isEmpty) {
      return false;
    }

    final lookupId = dbId.isNotEmpty ? dbId : clientMsgId;

    if (_processedMessageIds.contains(lookupId)) {
      final existingIdx = _messages.indexWhere((m) =>
          m.id == lookupId ||
          (clientMsgId.isNotEmpty &&
              (m.id == clientMsgId || m.clientMsgId == clientMsgId)));
      if (existingIdx != -1) {
        if (_messages[existingIdx].status != serverMessage.status ||
            _messages[existingIdx].isRead != serverMessage.isRead ||
            _messages[existingIdx].isDelivered != serverMessage.isDelivered) {
          _messages[existingIdx] = serverMessage;
          return true;
        }
      }
      return false;
    }

    final optimisticIndex = clientMsgId.isEmpty
        ? -1
        : _messages.indexWhere((message) =>
            message.id == clientMsgId || message.clientMsgId == clientMsgId);

    if (optimisticIndex != -1) {
      _messages[optimisticIndex] = serverMessage;
      if (clientMsgId.isNotEmpty) {
        _processedMessageIds.add(clientMsgId);
      }
      if (serverMessage.id.isNotEmpty) {
        _processedMessageIds.add(serverMessage.id);
      }
      return true;
    }
    if (serverMessage.id.isNotEmpty) {
      _processedMessageIds.add(serverMessage.id);
    }
    if (clientMsgId.isNotEmpty) {
      _processedMessageIds.add(clientMsgId);
    }
    _messages.add(serverMessage);
    return true;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _wsReconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;
    _realtimePollingTimer?.cancel();
    _inChatAdTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _currentUserId = '';

  Future<void> _loadUserStatus() async {
    final bool premium = await StorageManager.instance.isPremium();
    final String? uid = await StorageManager.instance.getUserId();
    setState(() {
      _isPremiumUser = premium;
      _currentUserId = uid ?? '';
    });

    if (!_isPremiumUser) {
      _startInChatAdTimer();
    }
  }

  Future<void> _fetchConsentStatus() async {
    try {
      final response = await ApiClient.instance.getBridgeStatus(widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _mutualMessageCount = data['total_messages'] ?? _mutualMessageCount;
          _myWhatsAppConsent = data['my_whatsapp_consent'] ?? false;
          _partnerWhatsAppConsent = data['partner_whatsapp_consent'] ?? false;
          _myLocationConsent = data['my_location_consent'] ?? false;
          _partnerLocationConsent = data['partner_location_consent'] ?? false;
          _myMeetupConsent = data['my_meetup_consent'] ?? false;
          _partnerMeetupConsent = data['partner_meetup_consent'] ?? false;
          _isMeetupUnlocked = data['is_meetup_unlocked'] ?? false;
          _myBridgePaid = data['my_payment_done'] ?? false;
          _partnerBridgePaid = data['partner_payment_done'] ?? false;
          _isWhatsAppUnlocked = data['whatsapp_unlocked'] ?? false;
          _isLocationUnlocked = data['location_unlocked'] ?? false;
          _unlockedPhoneNumber = data['partner_phone'];
          _partnerMapsUrl = data['partner_maps_url'];
        });
      }
    } catch (_) {
      _fetchWhatsAppBridgeStatus();
    }
  }

  Future<void> _submitMeetupConsent(bool agree) async {
    try {
      final res = await ApiClient.instance.updateMeetupConsent(
        matchId: widget.matchId,
        agree: agree,
      );
      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        setState(() {
          _myMeetupConsent = data['my_meetup_consent'] ?? agree;
          _partnerMeetupConsent =
              data['partner_meetup_consent'] ?? _partnerMeetupConsent;
          _isMeetupUnlocked = data['is_meetup_unlocked'] ?? false;
        });
      } else {
        setState(() => _myMeetupConsent = agree);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meetup consent notice: $e')),
        );
      }
    }
  }

  void _suggestSpotInChat(MeetupSpot spot) {
    final Map<String, dynamic> spotMetadata = {
      'spot_id': spot.id,
      'name': spot.name,
      'category': spot.categoryLabel,
      'distance_km': spot.distanceKm,
      'latitude': spot.latitude,
      'longitude': spot.longitude,
      'address': spot.address,
    };
    _sendMessage(
      text: 'Suggested a meetup spot: ${spot.name}',
      messageType: 'meetup_spot',
      metadata: spotMetadata,
    );
  }

  Future<void> _fetchWhatsAppBridgeStatus() async {
    try {
      final response = await ApiClient.instance
          .getWhatsAppBridgeStatus(matchId: widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _mutualMessageCount =
              data['total_messages'] ?? (data['mutual_message_count'] ?? 0);
          _myWhatsAppConsent = data['my_consent'] ?? false;
          _partnerWhatsAppConsent = data['partner_consent'] ?? false;
          _myBridgePaid = data['my_payment_done'] ?? false;
          _partnerBridgePaid = data['partner_payment_done'] ?? false;
          _isWhatsAppUnlocked = data['is_whatsapp_unlocked'] ??
              (data['is_fully_unlocked'] ?? false);
          _unlockedPhoneNumber = data['phone_number'] ?? data['partner_phone'];
        });
      }
    } catch (_) {}
  }

  Future<void> _launchWhatsAppChat() async {
    if (_unlockedPhoneNumber == null || _unlockedPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('WhatsApp phone number not available yet.')),
      );
      return;
    }
    String digitsOnly = _unlockedPhoneNumber!.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length == 10) {
      digitsOnly = '91$digitsOnly';
    }
    final uri = Uri.parse(
        'https://wa.me/$digitsOnly?text=${Uri.encodeComponent('Hi!')}');
    final nativeUri = Uri.parse(
        'whatsapp://send?phone=$digitsOnly&text=${Uri.encodeComponent('Hi!')}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchGoogleMapsRoute() async {
    if (_partnerMapsUrl == null || _partnerMapsUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps route not available yet.')),
      );
      return;
    }
    final uri = Uri.parse(_partnerMapsUrl!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Google Maps: $e')),
        );
      }
    }
  }

  void _startInChatAdTimer() {
    _inChatAdTimer?.cancel();
    _inChatAdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsActive++;
      if (_secondsActive >= 300) {
        _secondsActive = 0;
        _showInChatAdOverlay();
      }
    });
  }

  void _showInChatAdOverlay() {
    if (!mounted || _isPremiumUser) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.ondemand_video,
                color: AppTheme.secondaryColor, size: 26),
            SizedBox(width: 10),
            Text('In-Chat Video Ad (10s)',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          '5-Minute Conversation Ad Rule (Free Tier).\nTyping & messaging remain fully active underneath.\nUpgrade to ₹99/mo to disable all ads.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss',
                style: TextStyle(color: AppTheme.secondaryColor)),
          ),
        ],
      ),
    );
  }

  void _showMatchProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Header Image
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: _displayRecipient.avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(
                              _displayRecipient.avatarUrl,
                              maxHeight: 240,
                              maxWidth: 240,
                            )
                          : null,
                      child: _displayRecipient.avatarUrl.isEmpty
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white)
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _displayRecipient.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        if (_displayRecipient.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              color: Colors.blueAccent, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _displayRecipient.isOnline
                                ? Colors.greenAccent
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatRelativePresence(_displayRecipient.isOnline,
                              _displayRecipient.lastActiveAt),
                          style: TextStyle(
                            color: _displayRecipient.isOnline
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  size: 13, color: AppTheme.secondaryColor),
                              const SizedBox(width: 4),
                              Text(_recipientDistanceLabel,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bio Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About Me',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                          SizedBox(height: 6),
                          Text(
                            'Love authentic conversations over evening Chai ☕. Looking for genuine connections on UR-Heart.',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Report & Block Options
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showReportDialog();
                            },
                            icon: const Icon(Icons.report_problem,
                                color: AppTheme.secondaryColor, size: 18),
                            label: const Text('Report',
                                style:
                                    TextStyle(color: AppTheme.secondaryColor)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.secondaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showBlockConfirmDialog();
                            },
                            icon: const Icon(Icons.block,
                                color: Colors.redAccent, size: 18),
                            label: const Text('Block',
                                style: TextStyle(color: Colors.redAccent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({
    String? mediaUrl,
    String? text,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final String content = text ?? _messageController.text.trim();
    if (content.isEmpty && mediaUrl == null) return;

    final String actualSenderId =
        _currentUserId.isNotEmpty ? _currentUserId : 'current_user_id';
    final clientMsgId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: clientMsgId,
      clientMsgId: clientMsgId,
      senderId: actualSenderId,
      text: content,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      status: 'sending',
      isSent: false,
      isDelivered: false,
      isRead: false,
      messageType: messageType,
      metadata: metadata,
    );

    setState(() {
      _messages.add(newMessage);
      _processedMessageIds.add(clientMsgId);
      _messageController.clear();
      _mutualMessageCount++;

      // 15-Message Milestone Celebration
      if (_mutualMessageCount == 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '🎉 15 Messages Complete! Safe WhatsApp & Location Bridge is now available.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    try {
      final response = await ApiClient.instance.sendMessage(
        matchId: widget.matchId,
        clientMsgId: clientMsgId,
        content: content,
        mediaUrl: mediaUrl,
        messageType: messageType,
        metadata: metadata,
      );
      final data = response.data?['data'];
      if (data is Map && mounted) {
        setState(() {
          _upsertServerMessage(Map<String, dynamic>.from(data));
        });
      }
    } catch (e) {
      String errorMsg =
          '⚠️ Safe Bridge unlock hone se pehle number ya social handle share karna mana hai.';
      bool isSafeBridgeLocked = false;

      if (e is DioException && e.response != null) {
        final resData = e.response?.data;
        if (resData is Map) {
          // Backend structured SAFE_BRIDGE_LOCKED payload:
          // { "detail": { "error_code": "SAFE_BRIDGE_LOCKED", "detail": "..." } }
          String? code;
          String? message;

          // Check if detail is a nested Map containing error_code
          final detailObj = resData['detail'];
          if (detailObj is Map) {
            code = detailObj['error_code']?.toString();
            message = detailObj['detail']?.toString();
          } else {
            // Fallback: check root level for backward compatibility
            code = resData['error_code']?.toString();
            message = detailObj?.toString() ?? resData['message']?.toString();
          }

          if (message != null && message.isNotEmpty) {
            errorMsg = message;
          }

          // Detect Safe Bridge lock by error code OR by 400 + leak keywords
          if (code == 'SAFE_BRIDGE_LOCKED' ||
              code == 'MUTUAL_PAYMENT_REQUIRED' ||
              (e.response?.statusCode == 400 &&
               (errorMsg.toLowerCase().contains('safe bridge') ||
                errorMsg.toLowerCase().contains('contact') ||
                errorMsg.toLowerCase().contains('payment') ||
                errorMsg.toLowerCase().contains('locked')))) {
            isSafeBridgeLocked = true;
          }
        }
      }

      // Rollback optimistic message
      if (mounted) {
        setState(() {
          _messages.removeWhere(
              (m) => m.id == clientMsgId || m.clientMsgId == clientMsgId);
          _processedMessageIds.remove(clientMsgId);
          if (_mutualMessageCount > 0) _mutualMessageCount--;
          if (content.isNotEmpty && _messageController.text.isEmpty) {
            _messageController.text = content;
          }
        });

        // Special handling for Safe Bridge locked: vibrate + show paywall modal
        if (isSafeBridgeLocked) {
          try {
            // subtle haptic feedback
            HapticFeedback.vibrate();
          } catch (_) {}

          // Show an explanatory bottom sheet with direct action to unlock
          SafeBridgePaywallSheet.show(
            context: context,
            matchId: widget.matchId,
            partnerName: _displayRecipient.name,
            totalMessages: _mutualMessageCount,
            initialMyPaid: _myBridgePaid,
            initialPartnerPaid: _partnerBridgePaid,
          );

          // Also show a small SnackBar for immediate feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ Contact Details Locked — Both users must pay ₹499 to share phone numbers, social handles or UPI.',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.deepOrange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Unlock (₹499)',
                textColor: Colors.white,
                onPressed: () {
                  SafeBridgePaywallSheet.show(
                    context: context,
                    matchId: widget.matchId,
                    partnerName: _displayRecipient.name,
                    totalMessages: _mutualMessageCount,
                    initialMyPaid: _myBridgePaid,
                    initialPartnerPaid: _partnerBridgePaid,
                  );
                },
              ),
            ),
          );
        } else {
          // Generic error SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReportDialog() {
    String selectedReason = 'Inappropriate Content';
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.secondaryColor),
              const SizedBox(width: 10),
              Text('Report ${_displayRecipient.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select reason for reporting:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedReason,
                dropdownColor: AppTheme.surfaceColor,
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                      value: 'Inappropriate Content',
                      child: Text('Inappropriate Content')),
                  DropdownMenuItem(
                      value: 'Harassment or Bullying',
                      child: Text('Harassment or Bullying')),
                  DropdownMenuItem(
                      value: 'Fake Profile or Impersonation',
                      child: Text('Fake Profile or Impersonation')),
                  DropdownMenuItem(
                      value: 'Spam or Scam', child: Text('Spam or Scam')),
                  DropdownMenuItem(
                      value: 'Other Reason', child: Text('Other Reason')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await ApiClient.instance.reportUser(
                    reportedUserId: widget.recipientUser.id,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Report submitted. Thank you for keeping UR-Heart safe.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Notice: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.black),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text('Block ${_displayRecipient.name}?',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'They will no longer be able to see your profile or send you messages on UR-Heart.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              nav.pop();
              try {
                await ApiClient.instance
                    .blockUser(blockedUserId: widget.recipientUser.id);
                messenger.showSnackBar(
                  SnackBar(
                    content:
                        Text('Blocked ${_displayRecipient.name} successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                nav.pop(true);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Notice: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Block User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openMeetupActionsSheet() {
    final myPos = LocationService.instance.getLastCachedLocation();
    MeetupActionsSheet.show(
      context: context,
      matchId: widget.matchId,
      partnerName: _displayRecipient.name,
      totalMessages: _mutualMessageCount,
      isWhatsAppUnlocked: _isWhatsAppUnlocked,
      isLocationUnlocked: _isLocationUnlocked,
      partnerPhone: _unlockedPhoneNumber,
      partnerMapsUrl: _partnerMapsUrl,
      userLat: myPos?.latitude,
      userLon: myPos?.longitude,
      partnerLat: _displayRecipient.latitude,
      partnerLon: _displayRecipient.longitude,
      myWhatsAppConsent: _myWhatsAppConsent,
      partnerWhatsAppConsent: _partnerWhatsAppConsent,
      myLocationConsent: _myLocationConsent,
      partnerLocationConsent: _partnerLocationConsent,
      myMeetupConsent: _myMeetupConsent,
      partnerMeetupConsent: _partnerMeetupConsent,
      isMeetupUnlocked: _isMeetupUnlocked,
      myBridgePaid: _myBridgePaid,
      partnerBridgePaid: _partnerBridgePaid,
      onLaunchWhatsApp: _launchWhatsAppChat,
      onLaunchGoogleMaps: _launchGoogleMapsRoute,
      onSuggestSpotInChat: (spot) => _suggestSpotInChat(spot),
      onVoteMeetupConsent: (agree) => _submitMeetupConsent(agree),
      onRefreshStatus: _fetchConsentStatus,
    );
  }

  void _showUnsendMessageSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppTheme.cardBorderColor, width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.mutedTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Message Options',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.primaryColor, size: 20),
                ),
                title: const Text(
                  'Unsend Message',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Remove this message for both of you',
                  style: TextStyle(fontSize: 11, color: AppTheme.mutedTextColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndUnsendMessage(msg);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.mutedTextColor, size: 20),
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAndUnsendMessage(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded,
                color: AppTheme.primaryColor, size: 24),
            SizedBox(width: 10),
            Text('Unsend Message?',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Unsend this message? It will be removed for both of you in this conversation.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unsendMessage(msg.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unsend',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _unsendMessage(String messageId) async {
    // Optimistic local update
    setState(() {
      final idx = _messages
          .indexWhere((m) => m.id == messageId || m.clientMsgId == messageId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(isDeleted: true, text: '');
      }
    });

    try {
      await ApiClient.instance.unsendMessage(messageId: messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsend notice: $e')),
        );
      }
    }
  }

  Widget _buildSafeMeetAppBarPill() {
    final bool isBridgeActive = _isWhatsAppUnlocked ||
        _isLocationUnlocked ||
        (_myBridgePaid && _partnerBridgePaid);
    final bool bothMeetupAgreed =
        _isMeetupUnlocked || (_myMeetupConsent && _partnerMeetupConsent);

    return InkWell(
      onTap: _openMeetupActionsSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: bothMeetupAgreed
              ? const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                )
              : (isBridgeActive
                  ? LinearGradient(
                      colors: [Colors.teal.shade800, Colors.teal.shade500],
                    )
                  : null),
          color: (bothMeetupAgreed || isBridgeActive)
              ? null
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bothMeetupAgreed
                ? AppTheme.primaryColor
                : (isBridgeActive
                    ? Colors.tealAccent
                    : AppTheme.cardBorderColor),
            width: 1,
          ),
          boxShadow: (bothMeetupAgreed || isBridgeActive)
              ? [
                  BoxShadow(
                    color: (bothMeetupAgreed
                            ? AppTheme.primaryColor
                            : Colors.tealAccent)
                        .withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              bothMeetupAgreed
                  ? Icons.celebration_rounded
                  : (isBridgeActive
                      ? Icons.shield_rounded
                      : Icons.shield_outlined),
              size: 14,
              color: (bothMeetupAgreed || isBridgeActive)
                  ? Colors.white
                  : AppTheme.secondaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              bothMeetupAgreed
                  ? 'Safe Meet (2/2)'
                  : (isBridgeActive
                      ? 'Safe Meet Active'
                      : (_mutualMessageCount >= 15
                          ? 'Safe Share'
                          : '$_mutualMessageCount/15')),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: (bothMeetupAgreed || isBridgeActive)
                    ? Colors.white
                    : AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        titleSpacing: 0,
        title: InkWell(
          onTap:
              _isRecipientProfileLoading ? null : _showMatchProfileBottomSheet,
          child: _isRecipientProfileLoading
              ? const _RecipientHeaderLoadingPlaceholder()
              : Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryColor,
                          backgroundImage:
                              _displayRecipient.avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _displayRecipient.avatarUrl,
                                      maxHeight: 120,
                                      maxWidth: 120,
                                    )
                                  : null,
                          child: _displayRecipient.avatarUrl.isEmpty
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _displayRecipient.isOnline
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.surfaceColor, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_displayRecipient.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            if (_displayRecipient.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: Colors.blueAccent, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          _isTyping
                              ? 'typing...'
                              : '${formatRelativePresence(_displayRecipient.isOnline, _displayRecipient.lastActiveAt)} • $_recipientDistanceLabel',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isTyping
                                ? AppTheme.primaryColor
                                : (_displayRecipient.isOnline
                                    ? Colors.greenAccent
                                    : Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        actions: [
          // Sleek Safe Meet Action Pill in AppBar
          _buildSafeMeetAppBarPill(),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppTheme.cardColor,
            onSelected: (val) {
              if (val == 'safe_share') {
                _openMeetupActionsSheet();
              } else if (val == 'profile') {
                _showMatchProfileBottomSheet();
              } else if (val == 'report') {
                _showReportDialog();
              } else if (val == 'block') {
                _showBlockConfirmDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'safe_share',
                child: Row(
                  children: [
                    Icon(
                      (_isWhatsAppUnlocked || _isLocationUnlocked)
                          ? Icons.lock_open_rounded
                          : (_mutualMessageCount < 15
                              ? Icons.lock_clock
                              : Icons.shield_outlined),
                      color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                          ? Colors.greenAccent
                          : (_mutualMessageCount < 15
                              ? Colors.amber
                              : Colors.tealAccent),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mutualMessageCount < 15
                            ? 'Safe Share ($_mutualMessageCount/15)'
                            : 'Safe Share (WhatsApp/Maps/Spots)',
                        style: TextStyle(
                          color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                              ? Colors.greenAccent
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('View Profile', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report,
                        color: AppTheme.secondaryColor, size: 18),
                    SizedBox(width: 10),
                    Text('Report User', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Block User',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Direct DM Sachet Notice Banner
          if (widget.isDirectDM)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFFFB800)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ Direct DM Unlocked via ₹49 Sachet • Send your message directly!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 5-Min Ad Banner Notice for Free Tier Users
          if (!_isPremiumUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.secondaryColor.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.secondaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Free Tier: Next 10s video ad in ${300 - _secondsActive}s',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.secondaryColor),
                    ),
                  ),
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SubscriptionSheet(
                          initialPlanType: 'PLAN_AD_FREE_199'),
                    ),
                    child: const Text(
                      'Upgrade ₹199 VIP',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Messages List View (100% clean and dedicated to conversation)
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  color: AppTheme.primaryColor, size: 36),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Say Hi to ${_displayRecipient.name}! ✨',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Break the ice with a ready-to-tap conversation starter:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 16),

                            // 4-Action Icebreaker Starter Chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildIcebreakerChip(
                                    '☕ Chai date ke liye kab chalein?'),
                                _buildIcebreakerChip(
                                    '🎶 Aajkal kaun sa gaana loop pe chal raha hai?'),
                                _buildIcebreakerChip(
                                    '🌴 Shaam ko ghoomne ki best jagah kaun si hai?'),
                                _buildIcebreakerChip(
                                    '🎬 Koi achhi movie recommend karo!'),
                                _buildIcebreakerChip(
                                    '✨ Weekend ka kya plan hai?'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _sendMessage(
                                  text: 'Hi 👋 Great to match with you!'),
                              icon: const Icon(Icons.waving_hand, size: 16),
                              label: const Text('Send Quick Hi 👋',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    cacheExtent: 500,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isMe = (_currentUserId.isNotEmpty &&
                              (msg.senderId == _currentUserId ||
                               msg.senderId.trim().toLowerCase() == _currentUserId.trim().toLowerCase())) ||
                          msg.senderId == 'current_user_id' ||
                          (widget.recipientUser.id.isNotEmpty &&
                              msg.senderId.isNotEmpty &&
                              msg.senderId != widget.recipientUser.id);
                      final String timeStr =
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

                      return MessageBubbleWidget(
                        message: msg.text,
                        isMe: isMe,
                        time: timeStr,
                        mediaUrl: msg.mediaUrl,
                        messageType: msg.messageType,
                        metadata: msg.metadata,
                        senderAvatarUrl: _displayRecipient.avatarUrl,
                        status: msg.status,
                        isSent: msg.isSent,
                        isDelivered: msg.isDelivered,
                        isRead: msg.isRead,
                        isDeleted: msg.isDeleted,
                        onLongPress: isMe && !msg.isDeleted
                            ? () => _showUnsendMessageSheet(msg)
                            : null,
                      );
                    },
                  ),
          ),

          // Modern Floating Input Bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            color: AppTheme.surfaceColor,
            child: SafeArea(
              child: Row(
                children: [
                  // Floating Text Input Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type a warm message...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.sentiment_satisfied_alt,
                                color: Colors.white54, size: 22),
                            onPressed: () {
                              _messageController.text += ' 😊';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Micro-animated Send Button
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.sentBubbleGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcebreakerChip(String text) {
    return ActionChip(
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      label: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onPressed: () => _sendMessage(text: text),
    );
  }
}
