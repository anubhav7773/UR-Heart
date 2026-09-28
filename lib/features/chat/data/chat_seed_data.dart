import '../domain/chat_models.dart';

/// Deprecated mock data container — purged in Phase 2 in favor of live PostgreSQL endpoints
class ChatSeedData {
  static List<SparkProfile> getInitialSparks() {
    return const [];
  }

  static List<ChatConversation> getInitialConversations() {
    return const [];
  }

  static Map<String, List<ChatMessage>> getInitialMessages() {
    return const {};
  }
}
