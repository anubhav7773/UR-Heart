import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/features/chat/data/chat_repository.dart';
import 'package:ur_heart/features/chat/presentation/whatsapp_reveal_sheet.dart';

/// Screen 4: Production Protected Chat Room with Anti-Leak Rejection State & Real WebSocket
class ChatRoomScreen extends StatefulWidget {
  final String lang;
  final String matchId;
  final String participantName;
  final String participantId;
  final VoidCallback? onUnlockWhatsAppTap;

  const ChatRoomScreen({
    super.key,
    this.lang = 'en',
    this.matchId = 'd0000000-0000-0000-0000-000000000001',
    this.participantName = 'Priya Sharma',
    this.participantId = 'd2222222-2222-2222-2222-222222222222',
    this.onUnlockWhatsAppTap,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with SecureScreenMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatRepository _chatRepository;

  StreamSubscription? _msgSub;
  StreamSubscription? _leakSub;

  final List<ChatMessageModel> _messages = [];
  bool _hasAntiLeakViolation = false;
  String? _violationMessage;
  String? _currentUserId;

  // WhatsApp 3-Ad Reveal state
  int _userAdsWatched = 0;
  int _matchAdsWatched = 0;
  bool _isWhatsAppUnlocked = false;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _chatRepository = ChatRepository();

    // Default seed welcome conversation
    _messages.add(
      ChatMessageModel(
        id: 'msg_1',
        matchId: widget.matchId,
        senderId: widget.participantId,
        content: 'Namaste! Great to connect with you on UR-Heart. How was your day?',
        status: 'delivered',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    );

    _initWebSocket();
    _fetchWhatsAppProgress();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await _chatRepository.getHistory(widget.matchId);
      if (mounted && history.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(history);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Chat history load notice: $e");
    }
  }

  void _initWebSocket() {
    _chatRepository.connect();

    _msgSub = _chatRepository.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
        _scrollToBottom();
      }
    });

    _leakSub = _chatRepository.antiLeakAlertStream.listen((alertText) {
      if (mounted) {
        setState(() {
          _hasAntiLeakViolation = true;
          _violationMessage = alertText;
        });
      }
    });
  }

  Future<void> _fetchWhatsAppProgress() async {
    try {
      final dio = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      final res = await dio.get('/api/v1/ads/whatsapp-progress/${widget.matchId}');
      if (mounted && res.statusCode == 200 && res.data != null) {
        setState(() {
          _userAdsWatched = res.data['user_ads_watched'] as int? ?? 0;
          _matchAdsWatched = res.data['match_ads_watched'] as int? ?? 0;
          _isWhatsAppUnlocked = res.data['is_unlocked'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _onWatchAd() async {
    try {
      final dio = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      final res = await dio.post(
        '/api/v1/ads/complete-ad',
        data: {
          'ad_type': 'whatsapp_reveal',
          'target_id': widget.matchId,
        },
      );

      if (mounted && res.statusCode == 200) {
        setState(() {
          if (_userAdsWatched < 3) _userAdsWatched++;
          if (_userAdsWatched >= 3 && _matchAdsWatched >= 3) {
            _isWhatsAppUnlocked = true;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: URHeartColors.statusSuccess,
            content: Text('Reward verified! You have watched $_userAdsWatched of 3 ads.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_userAdsWatched < 3) _userAdsWatched++;
        });
      }
    }
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Check client-side regex for instant visual feedback on leaks
    final hasNumber = RegExp(r'\b\d{10}\b|\b[6-9]\d{9}\b').hasMatch(text);
    final hasSocial = RegExp(r'(insta|snap|telegram|whatsapp|wa|ig|@)', caseSensitive: false).hasMatch(text);

    if (hasNumber || hasSocial) {
      setState(() {
        _hasAntiLeakViolation = true;
        _violationMessage = 'Sharing phone numbers, social media handles (@, IG, WA, Snap) or external contacts is strictly prohibited on UR-Heart.';
        _messages.add(
          ChatMessageModel(
            id: UniqueKey().toString(),
            matchId: widget.matchId,
            senderId: _currentUserId ?? 'me',
            content: text,
            status: 'blocked',
            createdAt: DateTime.now(),
            isBlocked: true,
          ),
        );
      });
      _messageController.clear();
      _scrollToBottom();
      return;
    }

    // Normal safe message send over real WebSocket
    _chatRepository.sendMessage(
      matchId: widget.matchId,
      recipientId: widget.participantId,
      content: text,
    );

    setState(() {
      _hasAntiLeakViolation = false;
      _violationMessage = null;
      _messages.add(
        ChatMessageModel(
          id: UniqueKey().toString(),
          matchId: widget.matchId,
          senderId: _currentUserId ?? 'me',
          content: text,
          status: 'sent',
          createdAt: DateTime.now(),
        ),
      );
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openWhatsAppRevealSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WhatsAppRevealSheet(
        lang: widget.lang,
        userAdsWatched: _userAdsWatched,
        matchAdsWatched: _matchAdsWatched,
        onWatchAdTap: () {
          Navigator.of(ctx).pop();
          _onWatchAd();
        },
      ),
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _leakSub?.cancel();
    _chatRepository.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: URHeartColors.surfaceRaised,
                  child: Icon(Icons.person, color: URHeartColors.textSecondary, size: 20),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: URHeartColors.statusSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: URHeartColors.canvasBackground, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.participantName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _t('screenshotBlocked'),
                    style: const TextStyle(fontSize: 10.5, color: URHeartColors.brandSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Prominent Gold Button: Unlock WhatsApp 💬
          InkWell(
            onTap: _openWhatsAppRevealSheet,
            borderRadius: URHeartTheme.radiusPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isWhatsAppUnlocked
                    ? URHeartColors.statusSuccess.withValues(alpha: 0.2)
                    : URHeartColors.accentGold.withValues(alpha: 0.18),
                borderRadius: URHeartTheme.radiusPill,
                border: Border.all(
                  color: _isWhatsAppUnlocked ? URHeartColors.statusSuccess : URHeartColors.accentGold,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isWhatsAppUnlocked ? Icons.lock_open_rounded : Icons.chat_rounded,
                    size: 14,
                    color: _isWhatsAppUnlocked ? URHeartColors.statusSuccess : URHeartColors.accentGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isWhatsAppUnlocked ? 'WhatsApp Unlocked' : _t('waRevealButton'),
                    style: TextStyle(
                      color: _isWhatsAppUnlocked ? URHeartColors.statusSuccess : URHeartColors.accentGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Bubble Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg.senderId == (_currentUserId ?? 'me');

                  if (msg.isBlocked) {
                    return _buildBlockedBubble(msg);
                  }

                  return _buildBubble(
                    text: msg.content,
                    timestamp: '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                    isMe: isMe,
                    isDelivered: msg.status == 'delivered',
                  );
                },
              ),
            ),

            // High-Alert Bottom Red Banner (Gatekeeper Alert)
            if (_hasAntiLeakViolation)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: URHeartColors.statusDanger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: URHeartColors.statusDanger, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: URHeartColors.statusDanger, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('antiLeakTitle'),
                            style: const TextStyle(
                              color: URHeartColors.statusDanger,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _violationMessage ?? _t('antiLeakError'),
                            style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Input Dock
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: URHeartColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: URHeartTheme.radiusInput,
                          borderSide: BorderSide(
                            color: _hasAntiLeakViolation
                                ? URHeartColors.statusDanger
                                : URHeartColors.brandSecondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleSendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: URHeartTheme.minTouchTarget,
                      height: URHeartTheme.minTouchTarget,
                      decoration: BoxDecoration(
                        color: _hasAntiLeakViolation
                            ? URHeartColors.statusDanger.withValues(alpha: 0.3)
                            : URHeartColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble({
    required String text,
    required String timestamp,
    required bool isMe,
    bool isDelivered = false,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? URHeartColors.brandPrimary : URHeartColors.cardSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? Colors.transparent : URHeartColors.surfaceRaised,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9.5,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isDelivered ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12,
                    color: isDelivered ? URHeartColors.brandSecondary : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedBubble(ChatMessageModel msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: URHeartColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: URHeartColors.statusDanger, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: const TextStyle(
                color: URHeartColors.textMuted,
                fontSize: 13,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: URHeartColors.statusDanger, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Blocked • ${_t('antiLeakNoticeShort')}',
                  style: const TextStyle(
                    color: URHeartColors.statusDanger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
