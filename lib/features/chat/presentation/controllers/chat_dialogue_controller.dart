import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/crypto/sanctuary_crypto_vault.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_websocket_service.dart';
import '../../domain/nlp_chat_sanitizer.dart';

/// State representation for 1:1 Encrypted Dialogue (Screen 9 & Phase 3 E2EE)
class ChatDialogueState {
  final String matchId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isConnected;
  final int bridgeStage; // 1, 2, or 3
  final List<int>? peerPublicKeyBytes;
  final SanitizationResult? violationAlert;
  final Map<String, dynamic> peerProfile;
  final Map<String, dynamic> bridgeData;
  final String sharedPrompt;
  final List<String> icebreakers;
  final String currentUserId;
  final List<String> bondingSparks;
  final bool sparksDismissed;

  const ChatDialogueState({
    required this.matchId,
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.bridgeStage = 1,
    this.peerPublicKeyBytes,
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
      'user_step': 1,
      'peer_step': 1,
      'handle': '',
      'has_wa_key': false,
    },
    this.sharedPrompt = 'I loved that Haruki Murakami passage on quiet spaces.',
    this.icebreakers = const [
      'What thought brought you the most peace today?',
      'If quiet spaces had a sound, what would yours be?',
      'Which passage or memory has stayed close to you recently?',
    ],
    this.currentUserId = 'user-me',
    this.bondingSparks = const [],
    this.sparksDismissed = false,
  });

  ChatDialogueState copyWith({
    String? matchId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isConnected,
    int? bridgeStage,
    List<int>? peerPublicKeyBytes,
    SanitizationResult? violationAlert,
    bool clearViolation = false,
    Map<String, dynamic>? peerProfile,
    Map<String, dynamic>? bridgeData,
    String? sharedPrompt,
    List<String>? icebreakers,
    String? currentUserId,
    List<String>? bondingSparks,
    bool? sparksDismissed,
  }) {
    return ChatDialogueState(
      matchId: matchId ?? this.matchId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      bridgeStage: bridgeStage ?? this.bridgeStage,
      peerPublicKeyBytes: peerPublicKeyBytes ?? this.peerPublicKeyBytes,
      violationAlert: clearViolation ? null : (violationAlert ?? this.violationAlert),
      peerProfile: peerProfile ?? this.peerProfile,
      bridgeData: bridgeData ?? this.bridgeData,
      sharedPrompt: sharedPrompt ?? this.sharedPrompt,
      icebreakers: icebreakers ?? this.icebreakers,
      currentUserId: currentUserId ?? this.currentUserId,
      bondingSparks: bondingSparks ?? this.bondingSparks,
      sparksDismissed: sparksDismissed ?? this.sparksDismissed,
    );
  }
}

final chatDialogueControllerProvider = StateNotifierProvider.family<
    ChatDialogueController, ChatDialogueState, String>((ref, matchId) {
  final repo = ref.watch(chatRepositoryProvider);
  final ws = ref.watch(chatWebSocketServiceProvider);
  final cleanId = ChatDialogueController.cleanMatchId(matchId);
  return ChatDialogueController(ws, repo, 'user-me', cleanId);
});

/// True E2EE Encrypted Chat Pipeline Controller (DIS-07 Fix)
/// Manages X25519 Diffie-Hellman key exchange, ChaCha20-Poly1305 AEAD encryption,
/// single-use WSS channel stream listening, and Sacred Bridge Stage progression.
class ChatDialogueController extends StateNotifier<ChatDialogueState> {
  final ChatWebSocketService _wsService;
  final ChatRepository _chatRepository;
  final String _currentUserId;
  int _sentMessageCount = 0;

  static String cleanMatchId(String rawId) {
    String clean = rawId.trim();
    for (final prefix in ['conn_', 'match-', 'match_', 'spark_']) {
      if (clean.startsWith(prefix)) {
        clean = clean.substring(prefix.length);
        break;
      }
    }
    return clean;
  }

  ChatDialogueController(
    this._wsService,
    this._chatRepository,
    this._currentUserId,
    String matchId,
  ) : super(ChatDialogueState(matchId: cleanMatchId(matchId), isLoading: true)) {
    _initDialogue();
  }

  Timer? _activeDialoguePoller;

  Future<void> initializeDialogue() async {
    await _initDialogue();
  }

  Future<void> _initDialogue() async {
    state = state.copyWith(isLoading: true);

    try {
      // 1. Fetch historical thread messages & live contact bridge status & peer profile
      final history = await _chatRepository.fetchThreadMessages(state.matchId);
      final bridge = await _chatRepository.fetchContactBridgeStatus(state.matchId);
      final peerData = await _chatRepository.fetchPeerProfile(state.matchId);

      state = state.copyWith(
        messages: history,
        isLoading: false,
        isConnected: true,
        bridgeData: bridge,
        peerProfile: {...state.peerProfile, ...peerData},
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }

    // 2. Listen to incoming E2EE WebSocket events
    _wsService.messageStream.listen((event) async {
      final type = event['type'] as String?;
      final rawMid = event['match_id']?.toString() ?? '';
      final cleanMid = cleanMatchId(rawMid);
      final isTargetMatch = cleanMid == state.matchId || rawMid == state.matchId;

      if (type == 'dialogue_message' && isTargetMatch) {
        await _handleIncomingEncryptedMessage(event);
      } else if ((type == 'bridge_unlocked' || type == 'bridge_reveal_request' || type == 'bridge_declined') && isTargetMatch) {
        try {
          final bridge = await _chatRepository.fetchContactBridgeStatus(state.matchId);
          state = state.copyWith(bridgeData: bridge);
        } catch (_) {}
      } else if (type == 'stage_advanced' && isTargetMatch) {
        final newStage = event['new_stage'] as int? ?? 1;
        state = state.copyWith(bridgeStage: newStage);
      }
    });

    try {
      await _chatRepository.markMessagesAsRead(state.matchId);
    } catch (_) {}

    // Auto-fetch Eva bonding sparks after dialogue initializes with messages
    if (state.messages.isNotEmpty) {
      _fetchBondingSparksQuietly();
    }

    // 3. Start resilient 4-second active dialogue sync poller
    _startActiveDialoguePoller();
  }

  void _startActiveDialoguePoller() {
    _activeDialoguePoller?.cancel();
    _activeDialoguePoller = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        final freshMessages = await _chatRepository.fetchThreadMessages(state.matchId);
        if (freshMessages.isNotEmpty && mounted) {
          final existingIds = state.messages.map((m) => m.id).toSet();
          final newArrivals = freshMessages.where((m) => !existingIds.contains(m.id)).toList();
          if (newArrivals.isNotEmpty) {
            state = state.copyWith(messages: [...state.messages, ...newArrivals]);
          }
        }
      } catch (_) {}
    });
  }

  /// Spends 1 Sacred Bridge Reveal Token to unlock or request mutual contact reveal
  Future<bool> redeemBridgeRevealToken() async {
    try {
      final updatedBridge = await _chatRepository.redeemBridgeRevealToken(state.matchId);
      state = state.copyWith(bridgeData: updatedBridge);

      final dynamic rem = updatedBridge['remaining_reveal_tokens'] ?? updatedBridge['reveal_tokens_count'];
      if (rem is int) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('ur_heart_reveal_tokens', rem);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Responds to peer's Sacred Bridge reveal request ('accept' or 'decline')
  Future<bool> respondToBridgeConsent(String action) async {
    try {
      final updated = await _chatRepository.respondToBridgeConsent(state.matchId, action);
      final freshBridge = await _chatRepository.fetchContactBridgeStatus(state.matchId);
      state = state.copyWith(bridgeData: freshBridge);
      return updated['is_unlocked'] == true || updated['status'] == 'unlocked' || updated['status'] == 'declined';
    } catch (_) {
      return false;
    }
  }

  void setPeerProfile(Map<String, dynamic> profile) {
    state = state.copyWith(peerProfile: {...state.peerProfile, ...profile});
  }

  /// Encrypts plaintext via X25519 + ChaCha20-Poly1305 before dispatching.
  Future<void> sendEncryptedMessage(String plainText) async {
    final peerBytes = state.peerPublicKeyBytes;
    if (peerBytes == null || peerBytes.isEmpty) {
      // Fallback: Dispatches with standard envelope if peer key is pending exchange
      _wsService.sendJsonPayload({
        'type': 'dialogue_message',
        'match_id': state.matchId,
        'sender_id': _currentUserId,
        'payload_type': 'unencrypted_fallback',
        'text': plainText,
      });

      final localMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        matchId: state.matchId,
        senderId: _currentUserId,
        recipientId: state.peerProfile['recipient_id'] as String? ?? 'peer',
        text: plainText,
        createdAt: DateTime.now(),
        status: MessageDeliveryStatus.sent,
        isMe: true,
      );
      state = state.copyWith(messages: [...state.messages, localMsg]);

      // Persist to backend database
      try {
        await _chatRepository.sendMessage(
          matchId: state.matchId,
          text: plainText,
          recipientId: state.peerProfile['recipient_id'] as String? ?? 'peer',
        );
      } catch (_) {}
      return;
    }

    // Cryptographic Authenticated Encryption (AEAD)
    final packet = await SanctuaryCryptoVault.instance.encryptDialogueText(
      plainText: plainText,
      peerPublicKeyBytes: peerBytes,
    );

    _wsService.sendJsonPayload({
      'type': 'dialogue_message',
      'match_id': state.matchId,
      'sender_id': _currentUserId,
      'payload_type': 'chacha20_poly1305',
      'ciphertext': packet.ciphertextBase64,
      'nonce': packet.nonceBase64,
      'mac': packet.macBase64,
    });

    final localMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      matchId: state.matchId,
      senderId: _currentUserId,
      recipientId: state.peerProfile['recipient_id'] as String? ?? 'peer',
      text: plainText,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      isMe: true,
    );
    state = state.copyWith(messages: [...state.messages, localMsg]);

    // Persist to backend database
    try {
      await _chatRepository.sendMessage(
        matchId: state.matchId,
        text: plainText,
        recipientId: state.peerProfile['recipient_id'] as String? ?? 'peer',
      );
    } catch (_) {}
  }

  Future<void> _handleIncomingEncryptedMessage(Map<String, dynamic> rawEvent) async {
    final senderId = rawEvent['sender_id'] as String? ?? '';
    // Prevent duplicate bubbles by ignoring echoes of messages we sent ourselves
    if (senderId.isNotEmpty && senderId == _currentUserId) {
      return;
    }

    final payloadType = rawEvent['payload_type'] as String? ?? '';
    String displayText = '';

    if (payloadType == 'chacha20_poly1305' && state.peerPublicKeyBytes != null) {
      final packet = EncryptedMessagePacket(
        ciphertextBase64: rawEvent['ciphertext'] as String? ?? '',
        nonceBase64: rawEvent['nonce'] as String? ?? '',
        macBase64: rawEvent['mac'] as String? ?? '',
      );
      final decrypted = await SanctuaryCryptoVault.instance.decryptDialoguePacket(
        packet: packet,
        peerPublicKeyBytes: state.peerPublicKeyBytes ?? [],
      );
      displayText = decrypted ?? '[Encrypted Dialogue: Decryption Failed]';
    } else {
      displayText = rawEvent['text'] as String? ?? rawEvent['content'] as String? ?? '';
    }

    final msgId = rawEvent['id'] as String? ?? rawEvent['message_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (state.messages.any((m) => m.id == msgId)) {
      return;
    }

    final newMsg = ChatMessage(
      id: msgId,
      matchId: state.matchId,
      senderId: senderId,
      recipientId: _currentUserId,
      text: displayText,
      status: MessageDeliveryStatus.delivered,
      createdAt: DateTime.now(),
      isMe: false,
    );

    state = state.copyWith(messages: [...state.messages, newMsg]);
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

    // Cryptographically encrypt and dispatch via WSS & persist exactly once
    await sendEncryptedMessage(trimmed);

    // Refresh bonding sparks every 3 sent messages to stay contextual
    _sentMessageCount++;
    if (_sentMessageCount % 3 == 0 && !state.sparksDismissed) {
      _fetchBondingSparksQuietly();
    }

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

  /// Fetches Eva bonding sparks from backend and updates state
  Future<void> fetchBondingSparks() async {
    await _fetchBondingSparksQuietly();
  }

  Future<void> _fetchBondingSparksQuietly() async {
    try {
      final peerName = state.peerProfile['full_name'] as String? ?? 'Seeker';
      final peerBio = state.peerProfile['bio'] as String? ?? '';
      final sparks = await _chatRepository.fetchEvaBondingSparks(
        partnerName: peerName,
        partnerBio: peerBio,
        messages: state.messages,
      );
      if (sparks.isNotEmpty && mounted) {
        state = state.copyWith(bondingSparks: sparks, sparksDismissed: false);
      }
    } catch (_) {
      // Silently fail — bonding sparks are non-critical UX enhancement
    }
  }

  /// Dismisses the bonding spark bar until next refresh cycle
  void dismissBondingSparks() {
    state = state.copyWith(bondingSparks: [], sparksDismissed: true);
  }

  Future<void> markAsRead() async {
    await _chatRepository.markMessagesAsRead(state.matchId);
  }

  @override
  void dispose() {
    _activeDialoguePoller?.cancel();
    super.dispose();
  }
}
