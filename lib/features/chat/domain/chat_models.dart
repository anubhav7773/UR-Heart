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
    final rawClientId = json['client_id']?.toString();
    final rawId = json['id']?.toString();
    final effectiveId = (rawClientId != null && rawClientId.isNotEmpty)
        ? rawClientId
        : (rawId != null && rawId.isNotEmpty
            ? rawId
            : 'msg_${DateTime.now().millisecondsSinceEpoch}');

    return ChatMessage(
      id: effectiveId,
      matchId: json['match_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      text: json['text'] as String? ??
          json['content'] as String? ??
          json['message'] as String? ??
          json['encrypted_text'] as String? ??
          '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: _parseDeliveryStatus(json['status'] ?? json['delivery_status']),
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
  final bool isVerified;
  final String lastMessageText;
  final DateTime lastMessageTimestamp;
  final MessageDeliveryStatus lastMessageStatus;
  final int unreadCount;
  final String categoryTag;
  final String sharedContextQuote;
  final String bio;
  final String location;
  final String gender;
  List<String> interests;
  final String intentions;
  final String? closureStatus;
  final String? closedByUserId;
  final DateTime? closedAt;
  final String? closureTemplateKey;
  final String? closureNote;

  bool get isClosed => closureStatus == 'closed_with_grace';
  bool get isStagnant => closureStatus == 'stagnant';

  ChatConversation({
    required this.matchId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAge,
    required this.recipientAvatarUrl,
    required this.isOnline,
    required this.hasWaKey,
    this.isVerified = false,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.lastMessageStatus,
    required this.unreadCount,
    required this.categoryTag,
    required this.sharedContextQuote,
    this.bio = '',
    this.location = '',
    this.gender = '',
    this.interests = const [],
    this.intentions = '',
    this.closureStatus,
    this.closedByUserId,
    this.closedAt,
    this.closureTemplateKey,
    this.closureNote,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      matchId: json['match_id'] as String? ?? json['id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ??
          json['peer_id'] as String? ??
          json['partner_id'] as String? ??
          '',
      recipientName: json['recipient_name'] as String? ??
          json['peer_name'] as String? ??
          json['partner_name'] as String? ??
          json['full_name'] as String? ??
          json['name'] as String? ??
          'Sanctuary Seeker',
      recipientAge: json['recipient_age'] as int? ??
          json['peer_age'] as int? ??
          json['partner_age'] as int? ??
          json['age'] as int? ??
          24,
      recipientAvatarUrl: json['recipient_avatar_url'] as String? ??
          json['peer_photo'] as String? ??
          json['partner_photo'] as String? ??
          json['avatar_url'] as String? ??
          json['avatar'] as String? ??
          '',
      isOnline: json['is_online'] as bool? ?? true,
      hasWaKey: json['has_wa_key'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ??
          json['is_kyc_verified'] as bool? ??
          json['kyc_status'] as bool? ??
          false,
      bio: json['bio'] as String? ?? '',
      location: json['location'] as String? ?? json['city'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      intentions: json['intentions'] as String? ?? '',
      lastMessageText: json['last_message_text'] as String? ?? json['last_message'] as String? ?? '',
      lastMessageTimestamp: json['last_message_timestamp'] != null
          ? DateTime.tryParse(json['last_message_timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageStatus: ChatMessage._parseDeliveryStatus(json['last_message_status']),
      unreadCount: json['unread_count'] as int? ?? 0,
      categoryTag: json['category_tag'] as String? ?? 'Mutual Spark',
      sharedContextQuote: json['shared_context_quote'] as String? ?? '',
      closureStatus: json['closure_status'] as String?,
      closedByUserId: json['closed_by_user_id'] as String?,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'].toString()) : null,
      closureTemplateKey: json['closure_template_key'] as String?,
      closureNote: json['closure_note'] as String?,
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
    bool? isVerified,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    MessageDeliveryStatus? lastMessageStatus,
    int? unreadCount,
    String? categoryTag,
    String? sharedContextQuote,
    String? bio,
    String? location,
    String? gender,
    List<String>? interests,
    String? intentions,
    String? closureStatus,
    String? closedByUserId,
    DateTime? closedAt,
    String? closureTemplateKey,
    String? closureNote,
  }) {
    return ChatConversation(
      matchId: matchId ?? this.matchId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientAge: recipientAge ?? this.recipientAge,
      recipientAvatarUrl: recipientAvatarUrl ?? this.recipientAvatarUrl,
      isOnline: isOnline ?? this.isOnline,
      hasWaKey: hasWaKey ?? this.hasWaKey,
      isVerified: isVerified ?? this.isVerified,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      categoryTag: categoryTag ?? this.categoryTag,
      sharedContextQuote: sharedContextQuote ?? this.sharedContextQuote,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      intentions: intentions ?? this.intentions,
      closureStatus: closureStatus ?? this.closureStatus,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closedAt: closedAt ?? this.closedAt,
      closureTemplateKey: closureTemplateKey ?? this.closureTemplateKey,
      closureNote: closureNote ?? this.closureNote,
    );
  }
}

/// Compassionate closure template for Anti-Ghosting "Pass with Grace"
class MindfulClosureTemplate {
  final String key;
  final String title;
  final String icon;
  final String message;

  const MindfulClosureTemplate({
    required this.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  factory MindfulClosureTemplate.fromJson(Map<String, dynamic> json) {
    return MindfulClosureTemplate(
      key: json['key'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '🍃',
      message: json['message'] as String? ?? json['text'] as String? ?? '',
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
  final bool isVerified;
  final String bio;
  final String location;
  final String gender;
  final List<String> interests;
  final String intentions;

  const SparkProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.avatarUrl,
    required this.isOnline,
    required this.matchType,
    this.isVerified = false,
    this.bio = '',
    this.location = '',
    this.gender = '',
    this.interests = const [],
    this.intentions = '',
  });

  factory SparkProfile.fromJson(Map<String, dynamic> json) {
    return SparkProfile(
      id: json['id'] as String? ?? json['match_id'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String? ?? 'Seeker',
      age: json['age'] as int? ?? 24,
      avatarUrl: json['avatar_url'] as String? ??
          json['recipient_avatar_url'] as String? ??
          json['photo_url'] as String? ??
          '',
      isOnline: json['is_online'] as bool? ?? true,
      matchType: json['match_type'] as String? ?? 'MUTUAL',
      isVerified: json['is_verified'] as bool? ??
          json['is_kyc_verified'] as bool? ??
          json['kyc_status'] as bool? ??
          false,
      bio: json['bio'] as String? ?? '',
      location: json['location'] as String? ?? json['city'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      intentions: json['intentions'] as String? ?? '',
    );
  }
}
