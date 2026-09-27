import '../domain/chat_models.dart';

/// Seed data generator for simulated authentic chat threads & sparks
class ChatSeedData {
  static List<SparkProfile> getInitialSparks() {
    return const [
      SparkProfile(
        id: 'spark-1',
        name: 'Aanya',
        age: 26,
        avatarUrl: '',
        isOnline: true,
        matchType: 'MUTUAL',
      ),
      SparkProfile(
        id: 'spark-2',
        name: 'Rohan',
        age: 29,
        avatarUrl: '',
        isOnline: false,
        matchType: 'DIRECT MSG',
      ),
      SparkProfile(
        id: 'spark-3',
        name: 'Meera',
        age: 25,
        avatarUrl: '',
        isOnline: true,
        matchType: 'MUTUAL',
      ),
      SparkProfile(
        id: 'spark-4',
        name: 'Dev',
        age: 28,
        avatarUrl: '',
        isOnline: true,
        matchType: 'DIRECT MSG',
      ),
    ];
  }

  static List<ChatConversation> getInitialConversations() {
    return [
      ChatConversation(
        matchId: 'match-aarav-1',
        recipientId: 'user-aarav',
        recipientName: 'Aarav Sharma',
        recipientAge: 27,
        recipientAvatarUrl: '',
        isOnline: true,
        hasWaKey: false,
        lastMessageText: 'The quiet chapters of life always speak the loudest.',
        lastMessageTimestamp: DateTime.now().subtract(const Duration(minutes: 6)),
        lastMessageStatus: MessageDeliveryStatus.read,
        unreadCount: 0,
        categoryTag: 'Mutual Match · Books & Solitude',
        sharedContextQuote:
            'I loved that Haruki Murakami passage on quiet spaces you highlighted.',
      ),
      ChatConversation(
        matchId: 'match-meera-2',
        recipientId: 'user-meera',
        recipientName: 'Meera Sen',
        recipientAge: 25,
        recipientAvatarUrl: '',
        isOnline: true,
        hasWaKey: true,
        lastMessageText: 'Would love to hear your thoughts on that exhibition!',
        lastMessageTimestamp: DateTime.now().subtract(const Duration(hours: 2)),
        lastMessageStatus: MessageDeliveryStatus.delivered,
        unreadCount: 2,
        categoryTag: 'Mutual Match · Art & Galleries',
        sharedContextQuote: 'That painting you shared felt like autumn in the hills.',
      ),
      ChatConversation(
        matchId: 'match-kabir-3',
        recipientId: 'user-kabir',
        recipientName: 'Kabir Mehta',
        recipientAge: 28,
        recipientAvatarUrl: '',
        isOnline: false,
        hasWaKey: false,
        lastMessageText: 'Which roast do you gravitate towards most mornings?',
        lastMessageTimestamp: DateTime.now().subtract(const Duration(days: 1)),
        lastMessageStatus: MessageDeliveryStatus.sent,
        unreadCount: 0,
        categoryTag: 'Direct Request · Pour-Over & Travel',
        sharedContextQuote: 'A good morning ritual sets the tone for an honest day.',
      ),
    ];
  }

  static Map<String, List<ChatMessage>> getInitialMessages() {
    return {
      'match-aarav-1': [
        ChatMessage(
          id: 'msg-1',
          matchId: 'match-aarav-1',
          senderId: 'user-aarav',
          recipientId: 'me',
          text: 'Hello! I noticed we both find peace in early morning reading.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
          status: MessageDeliveryStatus.read,
          isMe: false,
        ),
        ChatMessage(
          id: 'msg-2',
          matchId: 'match-aarav-1',
          senderId: 'me',
          recipientId: 'user-aarav',
          text: 'Yes! Murakami captured that so gently in Norwegian Wood.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
          status: MessageDeliveryStatus.read,
          isMe: true,
        ),
        ChatMessage(
          id: 'msg-3',
          matchId: 'match-aarav-1',
          senderId: 'user-aarav',
          recipientId: 'me',
          text: 'The quiet chapters of life always speak the loudest.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
          status: MessageDeliveryStatus.read,
          isMe: false,
        ),
      ],
    };
  }
}
