/// Delivery status representing the WhatsApp-style 3-stage delivery pipeline
enum MessageDeliveryStatus {
  sent, // Single grey tick (fastapi/postgres saved)
  delivered, // Double grey tick (recipient socket acknowledged)
  read, // Double blue tick (recipient viewport viewed)
}

/// Domain entity representing a 1:1 text-only dialogue message
class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;
  final MessageDeliveryStatus status;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    required this.status,
    required this.isMe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      matchId: json['match_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      text: json['text'] as String? ?? json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: _parseDeliveryStatus(json['status']),
      isMe: json['is_me'] as bool? ?? false,
    );
  }

  static MessageDeliveryStatus _parseDeliveryStatus(dynamic status) {
    final s = status?.toString().toLowerCase();
    if (s == 'read') return MessageDeliveryStatus.read;
    if (s == 'delivered') return MessageDeliveryStatus.delivered;
    return MessageDeliveryStatus.sent;
  }

  ChatMessage copyWith({
    String? id,
    String? matchId,
    String? senderId,
    String? recipientId,
    String? text,
    DateTime? createdAt,
    MessageDeliveryStatus? status,
    bool? isMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
    );
  }
}

/// Domain entity representing an active dialogue in Screen 8 Chats Hub
class ChatConversation {
  final String matchId;
  final String recipientId;
  final String recipientName;
  final int recipientAge;
  final String recipientAvatarUrl;
  final bool isOnline;
  final bool hasWaKey;
  final String lastMessageText;
  final DateTime lastMessageTimestamp;
  final MessageDeliveryStatus lastMessageStatus;
  final int unreadCount;
  final String categoryTag;
  final String sharedContextQuote;

  const ChatConversation({
    required this.matchId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAge,
    required this.recipientAvatarUrl,
    required this.isOnline,
    required this.hasWaKey,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.lastMessageStatus,
    required this.unreadCount,
    required this.categoryTag,
    required this.sharedContextQuote,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      matchId: json['match_id'] as String? ?? json['id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? json['partner_id'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? json['full_name'] as String? ?? 'Sanctuary Seeker',
      recipientAge: json['recipient_age'] as int? ?? json['age'] as int? ?? 24,
      recipientAvatarUrl: json['recipient_avatar_url'] as String? ?? json['avatar_url'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      hasWaKey: json['has_wa_key'] as bool? ?? false,
      lastMessageText: json['last_message_text'] as String? ?? json['last_message'] as String? ?? '',
      lastMessageTimestamp: json['last_message_timestamp'] != null
          ? DateTime.tryParse(json['last_message_timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageStatus: ChatMessage._parseDeliveryStatus(json['last_message_status']),
      unreadCount: json['unread_count'] as int? ?? 0,
      categoryTag: json['category_tag'] as String? ?? 'Mutual Spark',
      sharedContextQuote: json['shared_context_quote'] as String? ?? '',
    );
  }

  ChatConversation copyWith({
    String? matchId,
    String? recipientId,
    String? recipientName,
    int? recipientAge,
    String? recipientAvatarUrl,
    bool? isOnline,
    bool? hasWaKey,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    MessageDeliveryStatus? lastMessageStatus,
    int? unreadCount,
    String? categoryTag,
    String? sharedContextQuote,
  }) {
    return ChatConversation(
      matchId: matchId ?? this.matchId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientAge: recipientAge ?? this.recipientAge,
      recipientAvatarUrl: recipientAvatarUrl ?? this.recipientAvatarUrl,
      isOnline: isOnline ?? this.isOnline,
      hasWaKey: hasWaKey ?? this.hasWaKey,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      categoryTag: categoryTag ?? this.categoryTag,
      sharedContextQuote: sharedContextQuote ?? this.sharedContextQuote,
    );
  }
}

typedef ConversationThread = ChatConversation;

/// Entity representing a spark candidate in the Screen 8 carousel
class SparkProfile {
  final String id;
  final String name;
  final int age;
  final String avatarUrl;
  final bool isOnline;
  final String matchType; // 'MUTUAL' or 'DIRECT MSG'

  const SparkProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.avatarUrl,
    required this.isOnline,
    required this.matchType,
  });

  factory SparkProfile.fromJson(Map<String, dynamic> json) {
    return SparkProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String? ?? 'Seeker',
      age: json['age'] as int? ?? 24,
      avatarUrl: json['avatar_url'] as String? ?? json['photo_url'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? true,
      matchType: json['match_type'] as String? ?? 'MUTUAL',
    );
  }
}
