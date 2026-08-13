import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../subscription/subscription_sheet.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String? mediaUrl;
  final bool isViewOnce;
  final DateTime timestamp;
  final bool isSent;
  final bool isDelivered;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.mediaUrl,
    this.isViewOnce = false,
    required this.timestamp,
    this.isSent = true,
    this.isDelivered = true,
    this.isRead = true,
  });
}

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String matchAvatarUrl;
  const ChatScreen({
    super.key,
    this.matchId = 'match_test_123',
    this.matchName = 'Priya',
    this.matchAvatarUrl = 'https://r2.ruralheart.com/priya_1.webp',
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

  // Safe WhatsApp Bridge State
  int _mutualMessageCount = 12;
  bool _isWhatsAppUnlocked = false;
  String? _unlockedPhoneNumber;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
    _fetchWhatsAppBridgeStatus();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await ApiClient.instance.getMessages(widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> rawMsgs = response.data['data'];
        setState(() {
          _messages.clear();
          for (var item in rawMsgs) {
            _messages.add(
              ChatMessage(
                id: item['id'] ?? '',
                senderId: item['sender_id'] ?? '',
                text: item['content'] ?? '',
                mediaUrl: item['media_url'],
                timestamp: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
              ),
            );
          }
        });
      }
    } catch (e) {
      // Empty message list fallback
    }
  }

  @override
  void dispose() {
    _inChatAdTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStatus() async {
    final bool premium = await StorageManager.instance.isPremium();
    setState(() {
      _isPremiumUser = premium;
    });

    if (!_isPremiumUser) {
      _startInChatAdTimer();
    }
  }

  Future<void> _fetchWhatsAppBridgeStatus() async {
    try {
      final response = await ApiClient.instance.getWhatsAppBridgeStatus(matchId: widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _mutualMessageCount = data['mutual_message_count'] ?? 12;
          _isWhatsAppUnlocked = data['is_whatsapp_unlocked'] ?? false;
          _unlockedPhoneNumber = data['phone_number'];
        });
      }
    } catch (e) {
      // Fallback state initialization
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
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.ondemand_video, color: Colors.amber, size: 26),
            SizedBox(width: 10),
            Text('In-Chat Video Ad (10s)', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          '5-Minute Conversation Ad Rule (Free Tier).\nTyping & messaging remain fully active underneath.\nUpgrade to ₹99/mo to disable all ads.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttachmentTap() async {
    if (!_isPremiumUser) {
      final bool? upgraded = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const SubscriptionSheet(),
      );

      if (upgraded == true) {
        setState(() {
          _isPremiumUser = true;
        });
        _inChatAdTimer?.cancel();
      }
    } else {
      _sendMessage(mediaUrl: 'https://r2.ruralheart.com/chat/sample_photo.webp', text: '📷 Shared a photo');
    }
  }

  void _sendMessage({String? mediaUrl, String? text}) {
    final String content = text ?? _messageController.text.trim();
    if (content.isEmpty && mediaUrl == null) return;

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'current_user_id',
      text: content,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
      _mutualMessageCount++;

      // Check if threshold of 15 mutual messages is met
      if (_mutualMessageCount >= 15 && !_isWhatsAppUnlocked) {
        _isWhatsAppUnlocked = true;
        _unlockedPhoneNumber = "+91 98765 43210";
      }
    });

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE91E63),
              backgroundImage: NetworkImage(widget.matchAvatarUrl),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.matchName, style: const TextStyle(fontSize: 16, color: Colors.white)),
                Text(
                  _isTyping ? 'typing...' : 'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isTyping ? const Color(0xFFE91E63) : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 5-Min Ad Banner Notice for Free Tier Users
          if (!_isPremiumUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Free Tier: Next 10s video ad in ${300 - _secondsActive}s',
                      style: const TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                  InkWell(
                    onTap: _handleAttachmentTap,
                    child: const Text(
                      'Upgrade ₹99',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Safe WhatsApp Bridge Progress & Unlock Header Widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[900],
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isWhatsAppUnlocked
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isWhatsAppUnlocked ? Colors.greenAccent : Colors.blueAccent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isWhatsAppUnlocked ? Icons.lock_open_rounded : Icons.shield_moon_outlined,
                    color: _isWhatsAppUnlocked ? Colors.greenAccent : Colors.blueAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isWhatsAppUnlocked ? 'Safe WhatsApp Bridge Unlocked!' : 'Safe WhatsApp Bridge Protection',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isWhatsAppUnlocked
                              ? 'WhatsApp: ${_unlockedPhoneNumber ?? "+91 98765 43210"}'
                              : 'Mutual Messages: $_mutualMessageCount/15 to reveal WhatsApp contact',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isWhatsAppUnlocked ? Colors.greenAccent : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isWhatsAppUnlocked)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: (_mutualMessageCount / 15).clamp(0.0, 1.0),
                        strokeWidth: 3,
                        color: Colors.blueAccent,
                        backgroundColor: Colors.grey[800],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Messages List View
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderId == 'current_user_id';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFE91E63) : Colors.grey[850],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all, size: 14, color: Colors.blueAccent),
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

          // Bottom Messaging Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            color: Colors.grey[900],
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment / Paywall Lock Button
                  IconButton(
                    icon: Icon(
                      _isPremiumUser ? Icons.photo_camera : Icons.lock_outline,
                      color: _isPremiumUser ? Colors.blueAccent : Colors.amber,
                    ),
                    onPressed: _handleAttachmentTap,
                  ),

                  // Message Input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Voice Note Button
                  IconButton(
                    icon: const Icon(Icons.mic, color: Colors.grey),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice note recorded (Unlimited on Free & Premium)')),
                      );
                    },
                  ),

                  // Send Button
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFFE91E63)),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
