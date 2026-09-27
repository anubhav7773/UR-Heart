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
}
