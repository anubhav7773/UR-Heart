import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/theme/app_theme.dart';
import '../subscription/subscription_sheet.dart';
import 'message_bubble.dart';

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

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _isLoading = true;
  List<dynamic> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.getChatConversations();
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> list = response.data['data'];
        setState(() {
          _conversations = list;
        });
      }
    } catch (e) {
      // Empty list fallback on network errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: const Text('Matches & Conversations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.favorite_outline, size: 64, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No matches yet!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Keep swiping on the feed to find your match and start chatting over Chai.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final item = _conversations[index];
                    final String matchId = item['match_id'] ?? item['id'] ?? '';
                    final String matchName = item['match_name'] ?? item['full_name'] ?? 'Match';
                    final String avatarUrl = item['avatar_url'] ?? item['photo_url'] ?? '';
                    final String lastMsg = item['last_message'] ?? 'Matched! Say hello 👋';

                    return ListTile(
                      onTap: () async {
                        final String targetUserId = item['target_user_id'] ?? item['target_id'] ?? '';
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              matchId: matchId,
                              matchName: matchName,
                              matchAvatarUrl: avatarUrl,
                              targetUserId: targetUserId,
                            ),
                          ),
                        );
                        if (res == true) {
                          _fetchConversations();
                        }
                      },
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.backgroundColor, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        matchName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    );
                  },
                ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String matchAvatarUrl;
  final String targetUserId;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.matchName,
    this.matchAvatarUrl = '',
    this.targetUserId = '',
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
  int _mutualMessageCount = 0;
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
          _mutualMessageCount = data['mutual_message_count'] ?? 0;
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
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.ondemand_video, color: AppTheme.secondaryColor, size: 26),
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
            child: const Text('Dismiss', style: TextStyle(color: AppTheme.secondaryColor)),
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
      _sendMessage(text: '📷 Shared photo attachment');
    }
  }

  Future<void> _sendChaiInviteDirect() async {
    try {
      final targetId = widget.targetUserId.isNotEmpty ? widget.targetUserId : widget.matchId;
      await ApiClient.instance.postSendChaiInvite(receiverId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ ₹9 Direct Invite Pass sent to ${widget.matchName}!'),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
      _sendMessage(text: '⚡ I sent you a Direct Invite Pass!');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chai Invite notice: ${e.toString()}')),
      );
    }
  }

  void _showMatchProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Header Image
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: widget.matchAvatarUrl.isNotEmpty ? NetworkImage(widget.matchAvatarUrl) : null,
                      child: widget.matchAvatarUrl.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.matchName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: AppTheme.secondaryColor),
                          SizedBox(width: 4),
                          Text('Within 3.4 km • Near Saket College', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bio Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About Me', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          SizedBox(height: 6),
                          Text(
                            'Love authentic conversations over evening Chai ☕. Looking for genuine connections on UR-Heart.',
                            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Action: Send Direct Invite Pass
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _sendChaiInviteDirect();
                      },
                      icon: const Icon(Icons.bolt, size: 20),
                      label: const Text('Send ₹9 Direct Pass (24 Hours)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Report & Block Options
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showReportDialog();
                            },
                            icon: const Icon(Icons.report_problem, color: AppTheme.secondaryColor, size: 18),
                            label: const Text('Report', style: TextStyle(color: AppTheme.secondaryColor)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.secondaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showBlockConfirmDialog();
                            },
                            icon: const Icon(Icons.block, color: Colors.redAccent, size: 18),
                            label: const Text('Block', style: TextStyle(color: Colors.redAccent)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({String? mediaUrl, String? text}) async {
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

      if (_mutualMessageCount >= 15 && !_isWhatsAppUnlocked) {
        _isWhatsAppUnlocked = true;
      }
    });

    try {
      await ApiClient.instance.sendMessage(
        matchId: widget.matchId,
        content: content,
        mediaUrl: mediaUrl,
      );
    } catch (_) {}

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

  void _showReportDialog() {
    String selectedReason = 'Inappropriate Content';
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.secondaryColor),
              const SizedBox(width: 10),
              Text('Report ${widget.matchName}', style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select reason for reporting:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedReason,
                dropdownColor: AppTheme.surfaceColor,
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'Inappropriate Content', child: Text('Inappropriate Content')),
                  DropdownMenuItem(value: 'Harassment or Bullying', child: Text('Harassment or Bullying')),
                  DropdownMenuItem(value: 'Fake Profile or Impersonation', child: Text('Fake Profile or Impersonation')),
                  DropdownMenuItem(value: 'Spam or Scam', child: Text('Spam or Scam')),
                  DropdownMenuItem(value: 'Other Reason', child: Text('Other Reason')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  final targetId = widget.targetUserId.isNotEmpty ? widget.targetUserId : widget.matchId;
                  await ApiClient.instance.reportUser(
                    reportedUserId: targetId,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. Thank you for keeping UR-Heart safe.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Notice: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, foregroundColor: Colors.black),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text('Block ${widget.matchName}?', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'They will no longer be able to see your profile or send you messages on UR-Heart.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              nav.pop();
              try {
                final targetId = widget.targetUserId.isNotEmpty ? widget.targetUserId : widget.matchId;
                await ApiClient.instance.blockUser(blockedUserId: targetId);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Blocked ${widget.matchName} successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                nav.pop(true);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Notice: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Block User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        titleSpacing: 0,
        title: InkWell(
          onTap: _showMatchProfileBottomSheet,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: widget.matchAvatarUrl.isNotEmpty ? NetworkImage(widget.matchAvatarUrl) : null,
                    child: widget.matchAvatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surfaceColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.matchName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    _isTyping ? 'typing...' : 'Online',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isTyping ? AppTheme.primaryColor : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Quick Action: Send ₹9 Direct Pass
          IconButton(
            tooltip: 'Send ₹9 Direct Pass',
            icon: const Icon(Icons.bolt, color: AppTheme.secondaryColor, size: 22),
            onPressed: _sendChaiInviteDirect,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppTheme.cardColor,
            onSelected: (val) {
              if (val == 'profile') {
                _showMatchProfileBottomSheet();
              } else if (val == 'report') {
                _showReportDialog();
              } else if (val == 'block') {
                _showBlockConfirmDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('View Profile', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, color: AppTheme.secondaryColor, size: 18),
                    SizedBox(width: 8),
                    Text('Report User', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Block User', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 5-Min Ad Banner Notice for Free Tier Users
          if (!_isPremiumUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.secondaryColor.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.secondaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Free Tier: Next 10s video ad in ${300 - _secondsActive}s',
                      style: const TextStyle(fontSize: 11, color: AppTheme.secondaryColor),
                    ),
                  ),
                  InkWell(
                    onTap: _handleAttachmentTap,
                    child: const Text(
                      'Upgrade ₹99',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Safe WhatsApp Bridge Progress & Unlock Header Widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surfaceColor,
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
                              ? 'WhatsApp: ${_unlockedPhoneNumber ?? "Contact Available"}'
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
            child: _messages.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(28),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryColor, size: 44),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Say Hi to ${widget.matchName}! ✨',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You matched! Start a warm conversation or share a photo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _sendMessage(text: 'Hi 👋 Great to match with you!'),
                            icon: const Icon(Icons.waving_hand, size: 18),
                            label: const Text('Send Quick Hi 👋'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == 'current_user_id';
                      final String timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

                      return MessageBubbleWidget(
                        message: msg.text,
                        isMe: isMe,
                        time: timeStr,
                        mediaUrl: msg.mediaUrl,
                        senderAvatarUrl: widget.matchAvatarUrl,
                      );
                    },
                  ),
          ),

          // Modern Floating Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            color: AppTheme.surfaceColor,
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment Button
                  IconButton(
                    icon: Icon(
                      _isPremiumUser ? Icons.photo_camera : Icons.lock_outline,
                      color: _isPremiumUser ? Colors.blueAccent : AppTheme.secondaryColor,
                    ),
                    onPressed: _handleAttachmentTap,
                  ),

                  // Floating Input Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type a warm message...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.sentiment_satisfied_alt, color: Colors.white54, size: 22),
                            onPressed: () {
                              _messageController.text += ' 😊';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Micro-animated Send Button
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.sentBubbleGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
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
