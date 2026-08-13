import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../subscription/subscription_sheet.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';

class ChatMessage {
  final String id;
  final String? clientMsgId;
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
    this.clientMsgId,
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

/// The person on the other side of a chat.
///
/// This is deliberately separate from the signed-in user: chat UI must never
/// infer its recipient from authentication or profile state.
class ChatRecipient {
  final String id;
  final String name;
  final String avatarUrl;

  const ChatRecipient({
    required this.id,
    required this.name,
    this.avatarUrl = '',
  });

  factory ChatRecipient.fromConversation(Map<String, dynamic> conversation) {
    return ChatRecipient(
      id: (conversation['target_user_id'] ?? conversation['target_id'] ?? '').toString(),
      name: (conversation['target_user_name'] ??
              conversation['full_name'] ??
              conversation['match_name'] ??
              '')
          .toString(),
      avatarUrl: (conversation['target_user_photo'] ??
              conversation['avatar_url'] ??
              conversation['photo_url'] ??
              '')
          .toString(),
    );
  }

  ChatRecipient copyWith({String? name, String? avatarUrl}) {
    return ChatRecipient(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class _RecipientHeaderLoadingPlaceholder extends StatelessWidget {
  const _RecipientHeaderLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
        const SizedBox(width: 10),
        Container(
          width: 96,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
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
                    final String matchId = item['id'] ?? item['match_id'] ?? '';
                    final recipientUser = ChatRecipient.fromConversation(
                      Map<String, dynamic>.from(item as Map),
                    );
                    final String matchName = recipientUser.name.isNotEmpty ? recipientUser.name : 'User';
                    final String avatarUrl = recipientUser.avatarUrl;
                    final String lastMsg = item['last_message'] ?? 'Matched! Say hello 👋';

                    return ListTile(
                      onTap: () async {
                        if (recipientUser.id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This conversation has no recipient. Please refresh and try again.')),
                          );
                          return;
                        }
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              matchId: matchId,
                              recipientUser: recipientUser,
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
  final ChatRecipient recipientUser;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.recipientUser,
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
  final Set<String> _processedMessageIds = {};
  Timer? _realtimePollingTimer;

  ChatRecipient? _recipientProfile;
  bool _isRecipientProfileLoading = true;
  String _recipientDistanceLabel = 'Online';

  ChatRecipient get _displayRecipient => _recipientProfile ?? widget.recipientUser;

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
    // Refresh the local GPS fix before calculating the recipient distance.
    LocationService.instance.getCurrentLocation();
    _fetchWhatsAppBridgeStatus();
    _fetchRecipientProfile();
    _fetchMessages();
    _startRealtimeStreamListener();
  }

  Future<void> _fetchRecipientProfile() async {
    try {
      final recipientId = widget.recipientUser.id;
      if (recipientId.isNotEmpty) {
        final response = await ApiClient.instance.dio.get(
          '/profile',
          queryParameters: {'user_id': recipientId},
        );
        if (response.data != null && response.data['data'] != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(response.data['data'] as Map);
          final returnedUserId = (data['user_id'] ?? data['id'] ?? '').toString();

          // A profile endpoint response for another account must identify that
          // account. Never let a response for the signed-in user overwrite the
          // recipient state, even if an older backend ignores `user_id`.
          if (returnedUserId != recipientId) return;

          if (mounted) {
            setState(() {
              final String name = (data['full_name'] ?? '').toString();
              String avatarUrl = widget.recipientUser.avatarUrl;
              final photos = data['photos'] as List<dynamic>?;
              if (photos != null && photos.isNotEmpty) {
                avatarUrl = photos.first.toString();
              }
              _recipientProfile = widget.recipientUser.copyWith(
                name: name.isNotEmpty ? name : widget.recipientUser.name,
                avatarUrl: avatarUrl,
              );

              final myPos = LocationService.instance.currentPosition;
              final double? rLat = (data['latitude'] as num?)?.toDouble();
              final double? rLng = (data['longitude'] as num?)?.toDouble();

              if (myPos != null && rLat != null && rLng != null) {
                final distKm = ChatProvider.calculateHaversineDistance(
                  lat1: myPos.latitude,
                  lon1: myPos.longitude,
                  lat2: rLat,
                  lon2: rLng,
                );
                _recipientDistanceLabel = ChatProvider.getFormattedDistanceLabel(distKm);
              } else if (data['area_name'] != null) {
                _recipientDistanceLabel = data['area_name'].toString();
              }
            });
          }
        }
      }
    } catch (_) {
      // Keep the explicitly supplied recipient visible; never substitute self.
    } finally {
      if (mounted) setState(() => _isRecipientProfileLoading = false);
    }
  }

  void _startRealtimeStreamListener() {
    _realtimePollingTimer?.cancel();
    _realtimePollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _fetchMessages(silent: true);
      }
    });
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    try {
      final response = await ApiClient.instance.getMessages(widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> rawMsgs = response.data['data'];

        bool changed = false;
        setState(() {
          for (final item in rawMsgs) {
            changed = _upsertServerMessage(Map<String, dynamic>.from(item as Map)) || changed;
          }
        });
        if (changed || (!silent && _messages.isNotEmpty)) _scrollToBottom();
      }
    } catch (_) {}
  }

  DateTime _parseLocalTimestamp(String isoTimestamp) {
    try {
      return DateTime.parse(isoTimestamp).toLocal();
    } on FormatException {
      return DateTime.now();
    }
  }

  /// Adds a server message once, or swaps an optimistic client message in place.
  bool _upsertServerMessage(Map<String, dynamic> data) {
    final dbId = (data['id'] ?? '').toString();
    final clientMsgId = (data['client_msg_id'] ?? '').toString();
    if (dbId.isEmpty) return false;

    final serverMessage = ChatMessage(
      id: dbId,
      clientMsgId: clientMsgId.isEmpty ? null : clientMsgId,
      senderId: (data['sender_id'] ?? '').toString(),
      text: (data['content'] ?? '').toString(),
      mediaUrl: data['media_url']?.toString(),
      timestamp: _parseLocalTimestamp((data['created_at'] ?? '').toString()),
      isSent: true,
    );
    if (_processedMessageIds.contains(dbId)) return false;

    final optimisticIndex = clientMsgId.isEmpty
        ? -1
        : _messages.indexWhere((message) =>
            message.id == clientMsgId || message.clientMsgId == clientMsgId);

    if (optimisticIndex != -1) {
      _messages[optimisticIndex] = serverMessage;
      _processedMessageIds..add(clientMsgId)..add(dbId);
      return true;
    }
    _processedMessageIds.add(dbId);
    if (clientMsgId.isNotEmpty) _processedMessageIds.add(clientMsgId);
    _messages.add(serverMessage);
    return true;
  }

  void _scrollToBottom() {
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
  void dispose() {
    _realtimePollingTimer?.cancel();
    _inChatAdTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _currentUserId = '';

  Future<void> _loadUserStatus() async {
    final bool premium = await StorageManager.instance.isPremium();
    final String? uid = await StorageManager.instance.getUserId();
    setState(() {
      _isPremiumUser = premium;
      _currentUserId = uid ?? '';
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
      await ApiClient.instance.postSendChaiInvite(receiverId: widget.recipientUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ ₹9 Direct Invite Pass sent to ${_displayRecipient.name}!'),
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
                      backgroundImage: _displayRecipient.avatarUrl.isNotEmpty ? NetworkImage(_displayRecipient.avatarUrl) : null,
                      child: _displayRecipient.avatarUrl.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _displayRecipient.name,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: AppTheme.secondaryColor),
                          SizedBox(width: 4),
                          Text(_recipientDistanceLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

    final String actualSenderId = _currentUserId.isNotEmpty ? _currentUserId : 'current_user_id';
    final clientMsgId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: clientMsgId,
      clientMsgId: clientMsgId,
      senderId: actualSenderId,
      text: content,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      isSent: false,
    );

    setState(() {
      _messages.add(newMessage);
      _processedMessageIds.add(clientMsgId);
      _messageController.clear();
      _mutualMessageCount++;

      if (_mutualMessageCount >= 15 && !_isWhatsAppUnlocked) {
        _isWhatsAppUnlocked = true;
      }
    });

    try {
      final response = await ApiClient.instance.sendMessage(
        matchId: widget.matchId,
        clientMsgId: clientMsgId,
        content: content,
        mediaUrl: mediaUrl,
      );
      final data = response.data?['data'];
      if (data is Map && mounted) {
        setState(() {
          _upsertServerMessage(Map<String, dynamic>.from(data));
        });
      }
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
              Text('Report ${_displayRecipient.name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
                  await ApiClient.instance.reportUser(
                    reportedUserId: widget.recipientUser.id,
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
            Text('Block ${_displayRecipient.name}?', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
                await ApiClient.instance.blockUser(blockedUserId: widget.recipientUser.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Blocked ${_displayRecipient.name} successfully.'),
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
          onTap: _isRecipientProfileLoading ? null : _showMatchProfileBottomSheet,
          child: _isRecipientProfileLoading
              ? const _RecipientHeaderLoadingPlaceholder()
              : Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: _displayRecipient.avatarUrl.isNotEmpty ? NetworkImage(_displayRecipient.avatarUrl) : null,
                    child: _displayRecipient.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
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
                  Text(_displayRecipient.name, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    _isTyping ? 'typing...' : 'Online • $_recipientDistanceLabel',
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
                            'Say Hi to ${_displayRecipient.name}! ✨',
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
                      final isMe = (_currentUserId.isNotEmpty && msg.senderId == _currentUserId) || msg.senderId == 'current_user_id';
                      final String timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

                      return MessageBubbleWidget(
                        message: msg.text,
                        isMe: isMe,
                        time: timeStr,
                        mediaUrl: msg.mediaUrl,
                        senderAvatarUrl: _displayRecipient.avatarUrl,
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
