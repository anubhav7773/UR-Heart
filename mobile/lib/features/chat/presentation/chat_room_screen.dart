import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/core/widgets/luxury_empty_card.dart';
import 'package:ur_heart/features/chat/data/chat_repository.dart';
import 'package:ur_heart/features/chat/presentation/whatsapp_reveal_sheet.dart';

/// Screen 4: Production Protected Chat Room with Anti-Leak Rejection State & Real WebSocket
class ChatRoomScreen extends StatefulWidget {
  final String lang;
  final String? matchId;
  final String? participantName;
  final String? participantId;
  final VoidCallback? onUnlockWhatsAppTap;

  const ChatRoomScreen({
    super.key,
    this.lang = 'en',
    this.matchId,
    this.participantName,
    this.participantId,
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
  StreamSubscription? _statusSub;
  StreamSubscription? _typingSub;
  bool _isPartnerTyping = false;
  Timer? _typingDebounce;

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

    if (widget.matchId != null && widget.matchId!.isNotEmpty) {
      _initWebSocket();
      _fetchWhatsAppProgress();
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    final mId = widget.matchId;
    if (mId == null || mId.isEmpty) return;
    try {
      final history = await _chatRepository.getHistory(mId);
      if (mounted && history.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(history);
        });
        _scrollToBottom();
        final pId = widget.participantId;
        if (pId != null) {
          _chatRepository.sendReadReceipt(matchId: mId, recipientId: pId);
        }
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

        final mId = widget.matchId;
        final pId = widget.participantId;
        if (mId != null && pId != null) {
          _chatRepository.sendDeliveryAck(matchId: mId, msgId: msg.id, recipientId: pId);
          _chatRepository.sendReadReceipt(matchId: mId, recipientId: pId);
        }
      }
    });

    _statusSub = _chatRepository.statusStream.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      if (type == 'read') {
        setState(() {
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i].senderId == (_currentUserId ?? 'me')) {
              _messages[i] = _messages[i].copyWith(status: 'read');
            }
          }
        });
      } else if (type == 'delivered') {
        final msgId = event['msg_id']?.toString();
        setState(() {
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i].id == msgId) {
              _messages[i] = _messages[i].copyWith(status: 'delivered');
            }
          }
        });
      } else if (type == 'message_sent') {
        final msgId = event['msg_id']?.toString();
        final status = event['status']?.toString() ?? 'sent';
        setState(() {
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].senderId == (_currentUserId ?? 'me')) {
              _messages[i] = _messages[i].copyWith(id: msgId, status: status);
              break;
            }
          }
        });
      }
    });

    _typingSub = _chatRepository.typingStream.listen((isTyping) {
      if (mounted) {
        setState(() {
          _isPartnerTyping = isTyping;
        });
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
    final mId = widget.matchId;
    if (mId == null || mId.isEmpty) return;
    try {
      final dio = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      final res = await dio.get('/api/v1/ads/whatsapp-progress/$mId');
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
    final mId = widget.matchId;
    if (mId == null || mId.isEmpty) return;
    try {
      final dio = createApiClient(baseUrl: EnvConfig.apiBaseUrl);
      final res = await dio.post(
        '/api/v1/ads/complete-ad',
        data: {
          'ad_type': 'whatsapp_reveal',
          'target_id': mId,
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
    final targetMatchId = widget.matchId;
    final targetRecipientId = widget.participantId;
    if (targetMatchId == null || targetRecipientId == null) return;

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
            matchId: targetMatchId,
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
      matchId: targetMatchId,
      recipientId: targetRecipientId,
      content: text,
    );

    setState(() {
      _hasAntiLeakViolation = false;
      _violationMessage = null;
      _messages.add(
        ChatMessageModel(
          id: UniqueKey().toString(),
          matchId: targetMatchId,
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
        matchPartnerName: widget.participantName ?? 'Match',
        userAdsWatched: _userAdsWatched,
        matchAdsWatched: _matchAdsWatched,
        targetUserId: widget.participantId,
        onWatchAdTap: _onWatchAd,
      ),
    );
  }

  void _onMessageTextChanged(String val) {
    final mId = widget.matchId;
    final pId = widget.participantId;
    if (mId == null || pId == null) return;

    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    if (val.trim().isNotEmpty) {
      _chatRepository.sendTyping(matchId: mId, recipientId: pId, isTyping: true);
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _chatRepository.sendTyping(matchId: mId, recipientId: pId, isTyping: false);
      });
    } else {
      _chatRepository.sendTyping(matchId: mId, recipientId: pId, isTyping: false);
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _leakSub?.cancel();
    _statusSub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    _chatRepository.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matchId == null || widget.matchId!.isEmpty) {
      return Scaffold(
        backgroundColor: URHeartColors.canvasBackground,
        appBar: AppBar(
          title: const Text('Direct Chat'),
        ),
        body: LuxuryEmptyCard(
          icon: Icons.chat_bubble_rounded,
          accentColor: const Color(0xFF08D9D6),
          title: "Direct Encrypted Chats",
          description: "Mutual matches and unlocked Second-Chance DMs will appear in this private ledger.",
          actionLabel: "Check Missed Connections",
          onAction: () {
            Navigator.of(context).pushNamed('/matches');
          },
        ),
      );
    }

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
                    widget.participantName ?? 'Match Partner',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isPartnerTyping ? 'typing...' : _t('screenshotBlocked'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _isPartnerTyping ? URHeartColors.accentGold : URHeartColors.brandSecondary,
                      fontWeight: _isPartnerTyping ? FontWeight.bold : FontWeight.normal,
                      fontStyle: _isPartnerTyping ? FontStyle.italic : FontStyle.normal,
                    ),
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
                  Text(_isWhatsAppUnlocked ? '🟢' : '💬', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    _isWhatsAppUnlocked ? 'WA Unlocked' : 'Unlock WA',
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
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mark_chat_read_outlined,
                            size: 48,
                            color: URHeartColors.brandSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Break the ice! Say hello to your match.',
                            style: TextStyle(
                              color: URHeartColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildE2eeBanner();
                        }
                        final msg = _messages[index - 1];
                        final isMe = msg.senderId == (_currentUserId ?? 'me');

                        if (msg.isBlocked) {
                          return _buildBlockedBubble(msg);
                        }

                        return _buildBubble(
                          text: msg.content,
                          timestamp:
                              '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                          isMe: isMe,
                          status: msg.status,
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
                      onChanged: _onMessageTextChanged,
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

  Widget _buildE2eeBanner() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: URHeartColors.surfaceRaised.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: URHeartColors.surfaceRaised),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: URHeartColors.accentGold),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Messages are end-to-end encrypted with AES-256.',
                textAlign: TextAlign.center,
                style: TextStyle(color: URHeartColors.textMuted, fontSize: 10.5),
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
    required String status,
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
                  _buildStatusTicks(status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTicks(String status) {
    if (status == 'read') {
      // Double Blue Tick (Official WhatsApp blue)
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Color(0xFF34B7F1),
      );
    } else if (status == 'delivered') {
      // Double Grey Tick
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Colors.white70,
      );
    } else {
      // Single Grey Tick
      return const Icon(
        Icons.done_rounded,
        size: 14,
        color: Colors.white70,
      );
    }
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
