import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chat_repository.dart';
import '../../domain/nlp_chat_sanitizer.dart';

/// State representation for 1:1 Encrypted Dialogue (Screen 9)
class ChatDialogueState {
  final String matchId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final SanitizationResult? violationAlert;
  final Map<String, dynamic> peerProfile;
  final Map<String, dynamic> bridgeData;
  final String sharedPrompt;
  final List<String> icebreakers;
  final String currentUserId;

  const ChatDialogueState({
    required this.matchId,
    required this.messages,
    this.isLoading = false,
    this.violationAlert,
    this.peerProfile = const {
      'full_name': 'Meera Sen',
      'avatar_url': null,
      'is_online': true,
      'recipient_id': 'user-meera',
    },
    this.bridgeData = const {
      'is_unlocked': false,
      'platform': 'whatsapp',
      'user_step': 2,
      'peer_step': 1,
      'handle': '+919876543210',
      'has_wa_key': true,
    },
    this.sharedPrompt = 'I loved that Haruki Murakami passage on quiet spaces.',
    this.icebreakers = const [
      'What thought brought you the most peace today?',
      'If quiet spaces had a sound, what would yours be?',
      'Which passage or memory has stayed close to you recently?',
    ],
    this.currentUserId = 'user-me',
  });

  ChatDialogueState copyWith({
    String? matchId,
    List<ChatMessage>? messages,
    bool? isLoading,
    SanitizationResult? violationAlert,
    bool clearViolation = false,
    Map<String, dynamic>? peerProfile,
    Map<String, dynamic>? bridgeData,
    String? sharedPrompt,
    List<String>? icebreakers,
    String? currentUserId,
  }) {
    return ChatDialogueState(
      matchId: matchId ?? this.matchId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      violationAlert: clearViolation ? null : (violationAlert ?? this.violationAlert),
      peerProfile: peerProfile ?? this.peerProfile,
      bridgeData: bridgeData ?? this.bridgeData,
      sharedPrompt: sharedPrompt ?? this.sharedPrompt,
      icebreakers: icebreakers ?? this.icebreakers,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

final chatDialogueControllerProvider = StateNotifierProvider.family<
    ChatDialogueController, ChatDialogueState, String>((ref, matchId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatDialogueController(matchId, repo);
});

/// Message queue, optimistic dispatch & 3-stage delivery synchronization
class ChatDialogueController extends StateNotifier<ChatDialogueState> {
  final String _matchId;
  final ChatRepository _repo;

  ChatDialogueController(this._matchId, this._repo)
      : super(ChatDialogueState(matchId: _matchId, messages: [], isLoading: true)) {
    initializeDialogue();
  }

  Future<void> initializeDialogue() async {
    state = state.copyWith(isLoading: true);
    final msgs = await _repo.getMessagesForMatch(_matchId);
    state = state.copyWith(
      messages: msgs,
      isLoading: false,
      bridgeData: {
        'is_unlocked': false,
        'platform': 'whatsapp',
        'user_step': 2,
        'peer_step': 1,
        'handle': '+919876543210',
        'has_wa_key': true,
      },
    );
    await _repo.markMessagesAsRead(_matchId);
  }

  Future<bool> sendMessage(String text) async {
    return sendHeartfeltMessage(
      text: text,
      recipientId: state.peerProfile['recipient_id'] as String? ?? 'user-meera',
    );
  }

  Future<bool> sendHeartfeltMessage({
    required String text,
    required String recipientId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Execute Client-Side NLP Gatekeeper inspection
    final inspection = NlpChatSanitizer.inspect(trimmed);
    if (!inspection.isValid) {
      state = state.copyWith(violationAlert: inspection);
      return false;
    }

    state = state.copyWith(clearViolation: true);

    final sentMsg = await _repo.sendMessage(
      matchId: _matchId,
      text: trimmed,
      recipientId: recipientId,
    );

    final updated = List<ChatMessage>.from(state.messages)..add(sentMsg);
    state = state.copyWith(messages: updated);
    return true;
  }

  void updateBridgeData(Map<String, dynamic> data) {
    state = state.copyWith(bridgeData: {...state.bridgeData, ...data});
  }

  void updateDeliveryTick(String messageId, MessageDeliveryStatus status) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void setViolationAlert(String violationMessage) {
    state = state.copyWith(
      violationAlert: SanitizationResult(
        isValid: false,
        violationCode: 'PHONE_NUMBER_DETECTED',
        userFriendlyMessage: 'Sharing phone numbers is strictly shielded. $violationMessage',
      ),
    );
  }

  void dismissViolationAlert() {
    state = state.copyWith(clearViolation: true);
  }

  Future<void> markAsRead() async {
    await _repo.markMessagesAsRead(_matchId);
  }
}
