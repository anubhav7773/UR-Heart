import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/security/flutter_windowmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../subscription/subscription_sheet.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'widgets/consent_dialog.dart';

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
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastActiveAt;

  const ChatRecipient({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.isVerified = false,
    this.isOnline = false,
    this.lastActiveAt,
  });

  factory ChatRecipient.fromConversation(Map<String, dynamic> conversation) {
    DateTime? lastActive;
    final lastSeenStr = conversation['last_active_at'] ?? conversation['last_seen'];
    if (lastSeenStr != null) {
      try {
        lastActive = DateTime.parse(lastSeenStr.toString()).toLocal();
      } catch (_) {}
    }
    final bool isOnline = conversation['is_online'] == true;

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
      isVerified: conversation['is_verified'] ?? conversation['is_verified_local'] ?? false,
      isOnline: isOnline,
      lastActiveAt: lastActive,
    );
  }

  ChatRecipient copyWith({
    String? name,
    String? avatarUrl,
    bool? isVerified,
    bool? isOnline,
    DateTime? lastActiveAt,
  }) {
    return ChatRecipient(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

String formatRelativePresence(bool isOnline, DateTime? lastActive) {
  if (isOnline) return 'Online';
  if (lastActive == null) return 'Offline';

  final diff = DateTime.now().difference(lastActive);
  if (diff.inSeconds < 180) {
    return 'Online';
  } else if (diff.inMinutes < 60) {
    final mins = diff.inMinutes;
    return 'Active ${mins <= 1 ? 1 : mins}m ago';
  } else if (diff.inHours < 24) {
    final hours = diff.inHours;
    return 'Active ${hours}h ago';
  } else if (diff.inDays == 1) {
    return 'Active yesterday';
  } else if (diff.inDays < 7) {
    return 'Active ${diff.inDays}d ago';
  } else {
    return 'Active recently';
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
                            backgroundImage: avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    avatarUrl,
                                    maxHeight: 120,
                                    maxWidth: 120,
                                  )
                                : null,
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

  // Safe WhatsApp & Location Bridge State
  int _mutualMessageCount = 0;
  bool _myWhatsAppConsent = false;
  bool _partnerWhatsAppConsent = false;
  bool _isWhatsAppUnlocked = false;
  String? _unlockedPhoneNumber;

  bool _myLocationConsent = false;
  bool _partnerLocationConsent = false;
  bool _isLocationUnlocked = false;
  String? _partnerMapsUrl;

  bool _isConsentLoading = false;

  final List<ChatMessage> _messages = [];
  final Set<String> _processedMessageIds = {};
  Timer? _realtimePollingTimer;

  ChatRecipient? _recipientProfile;
  bool _isRecipientProfileLoading = true;
  String _recipientDistanceLabel = 'Location pending';

  ChatRecipient get _displayRecipient => _recipientProfile ?? widget.recipientUser;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _loadUserStatus();
    // Refresh the local GPS fix before calculating the recipient distance.
    LocationService.instance.getCurrentLocation().then((position) {
      if (position == null && mounted && _recipientDistanceLabel == 'Location pending') {
        setState(() => _recipientDistanceLabel = 'Location unavailable');
      }
    });
    _fetchConsentStatus();
    _fetchRecipientProfile();
    _fetchMessages();
    _startRealtimeStreamListener();
  }

  Future<void> _enableScreenshotProtection() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        if (kDebugMode) print('Could not enable FLAG_SECURE: $e');
      }
    }
  }

  Future<void> _disableScreenshotProtection() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        if (kDebugMode) print('Could not clear FLAG_SECURE: $e');
      }
    }
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
              DateTime? lastActive;
              final lastSeenStr = data['last_active_at'] ?? data['last_seen'];
              if (lastSeenStr != null) {
                try {
                  lastActive = DateTime.parse(lastSeenStr.toString()).toLocal();
                } catch (_) {}
              }
              final bool isOnline = data['is_online'] == true;

              _recipientProfile = widget.recipientUser.copyWith(
                name: name.isNotEmpty ? name : widget.recipientUser.name,
                avatarUrl: avatarUrl,
                isVerified: data['is_verified'] ?? data['is_verified_local'] ?? false,
                isOnline: isOnline,
                lastActiveAt: lastActive,
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
    _disableScreenshotProtection();
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

  Future<void> _fetchConsentStatus() async {
    try {
      final response = await ApiClient.instance.getChatConsent(matchId: widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _myWhatsAppConsent = data['my_whatsapp_consent'] ?? false;
          _partnerWhatsAppConsent = data['partner_whatsapp_consent'] ?? false;
          _isWhatsAppUnlocked = data['whatsapp_unlocked'] ?? false;
          _unlockedPhoneNumber = data['partner_phone'];

          _myLocationConsent = data['my_location_consent'] ?? false;
          _partnerLocationConsent = data['partner_location_consent'] ?? false;
          _isLocationUnlocked = data['location_unlocked'] ?? false;
          _partnerMapsUrl = data['partner_maps_url'];
        });
      }
    } catch (_) {
      _fetchWhatsAppBridgeStatus();
    }
  }

  Future<void> _fetchWhatsAppBridgeStatus() async {
    try {
      final response = await ApiClient.instance.getWhatsAppBridgeStatus(matchId: widget.matchId);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _mutualMessageCount = data['mutual_message_count'] ?? 0;
          _myWhatsAppConsent = data['my_consent'] ?? false;
          _partnerWhatsAppConsent = data['partner_consent'] ?? false;
          _isWhatsAppUnlocked = data['is_whatsapp_unlocked'] ?? false;
          _unlockedPhoneNumber = data['phone_number'];
        });
      }
    } catch (_) {}
  }

  Future<void> _openSafeShareDialog() async {
    final result = await ConsentDialog.show(
      context: context,
      initialShareWhatsapp: _myWhatsAppConsent,
      initialShareLocation: _myLocationConsent,
      partnerName: _displayRecipient.name,
      partnerWhatsAppConsent: _partnerWhatsAppConsent,
      partnerLocationConsent: _partnerLocationConsent,
    );

    if (result == null || !mounted) return;

    setState(() => _isConsentLoading = true);
    try {
      final response = await ApiClient.instance.submitChatConsent(
        matchId: widget.matchId,
        shareWhatsapp: result.shareWhatsapp,
        shareLocation: result.shareLocation,
      );

      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        setState(() {
          _myWhatsAppConsent = data['my_whatsapp_consent'] ?? result.shareWhatsapp;
          _myLocationConsent = data['my_location_consent'] ?? result.shareLocation;
          _partnerWhatsAppConsent = data['partner_whatsapp_consent'] ?? false;
          _partnerLocationConsent = data['partner_location_consent'] ?? false;
          _isWhatsAppUnlocked = data['whatsapp_unlocked'] ?? false;
          _isLocationUnlocked = data['location_unlocked'] ?? false;
          _unlockedPhoneNumber = data['partner_phone'];
          _partnerMapsUrl = data['partner_maps_url'];
        });

        if (mounted) {
          String feedback = '✅ Sharing preferences updated.';
          if (_isWhatsAppUnlocked && _isLocationUnlocked) {
            feedback = '🎉 WhatsApp & Google Maps Route Unlocked!';
          } else if (_isWhatsAppUnlocked) {
            feedback = '🎉 WhatsApp Unlocked! You can now chat directly.';
          } else if (_isLocationUnlocked) {
            feedback = '🎉 Live Route on Google Maps Unlocked!';
          } else if (result.shareWhatsapp || result.shareLocation) {
            feedback = '✅ Consent recorded. Waiting for ${_displayRecipient.name}\'s consent.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(feedback),
              backgroundColor: (_isWhatsAppUnlocked || _isLocationUnlocked)
                  ? Colors.green.shade700
                  : Colors.amber.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update consent: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConsentLoading = false);
    }
  }

  Future<void> _launchWhatsAppChat() async {
    if (_unlockedPhoneNumber == null || _unlockedPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp phone number not available yet.')),
      );
      return;
    }
    final cleanPhone = _unlockedPhoneNumber!.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    final webUri = Uri.parse('https://wa.me/$cleanPhone');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchGoogleMapsRoute() async {
    if (_partnerMapsUrl == null || _partnerMapsUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps route not available yet.')),
      );
      return;
    }
    final uri = Uri.parse(_partnerMapsUrl!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Google Maps: $e')),
        );
      }
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
      await ApiClient.instance.postSendChaiInvite(
        receiverId: widget.recipientUser.id,
        matchId: widget.matchId,
        message: '⚡ I sent you a ₹9 Direct Invite Pass!',
      );
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
                      backgroundImage: _displayRecipient.avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(
                              _displayRecipient.avatarUrl,
                              maxHeight: 240,
                              maxWidth: 240,
                            )
                          : null,
                      child: _displayRecipient.avatarUrl.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _displayRecipient.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (_displayRecipient.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _displayRecipient.isOnline ? Colors.greenAccent : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatRelativePresence(_displayRecipient.isOnline, _displayRecipient.lastActiveAt),
                          style: TextStyle(
                            color: _displayRecipient.isOnline ? Colors.greenAccent : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 13, color: AppTheme.secondaryColor),
                              const SizedBox(width: 4),
                              Text(_recipientDistanceLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
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
                    backgroundImage: _displayRecipient.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(
                            _displayRecipient.avatarUrl,
                            maxHeight: 120,
                            maxWidth: 120,
                          )
                        : null,
                    child: _displayRecipient.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _displayRecipient.isOnline ? Colors.greenAccent : Colors.grey,
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
                  Row(
                    children: [
                      Text(_displayRecipient.name, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      if (_displayRecipient.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    _isTyping
                        ? 'typing...'
                        : '${formatRelativePresence(_displayRecipient.isOnline, _displayRecipient.lastActiveAt)} • $_recipientDistanceLabel',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isTyping
                          ? AppTheme.primaryColor
                          : (_displayRecipient.isOnline ? Colors.greenAccent : Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // 🔒 Safe Share Action
          TextButton.icon(
            key: const Key('safe_share_action_button'),
            onPressed: _openSafeShareDialog,
            icon: const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 18),
            label: const Text(
              '🔒 Safe Share',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
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

          // Safe Two-Way Consent Bridge (WhatsApp & Live Route) Header Widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppTheme.surfaceColor,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                    ? Colors.green.withValues(alpha: 0.15)
                    : (_myWhatsAppConsent || _myLocationConsent)
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                      ? Colors.greenAccent
                      : (_myWhatsAppConsent || _myLocationConsent)
                          ? Colors.amber
                          : Colors.tealAccent,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        (_isWhatsAppUnlocked && _isLocationUnlocked)
                            ? Icons.lock_open_rounded
                            : (_myWhatsAppConsent || _myLocationConsent)
                                ? Icons.hourglass_top_rounded
                                : Icons.shield_outlined,
                        color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                            ? Colors.greenAccent
                            : (_myWhatsAppConsent || _myLocationConsent)
                                ? Colors.amber
                                : Colors.tealAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_isWhatsAppUnlocked && _isLocationUnlocked)
                                  ? '🎉 Safe Contact & Live Route Unlocked!'
                                  : _isWhatsAppUnlocked
                                      ? '🎉 Safe WhatsApp Unlocked!'
                                      : _isLocationUnlocked
                                          ? '🎉 Live Route on Maps Unlocked!'
                                          : (_myWhatsAppConsent || _myLocationConsent)
                                              ? 'Consent Shared 🤝'
                                              : 'Safe Contact & Route Sharing',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (_isWhatsAppUnlocked && _isLocationUnlocked)
                                  ? 'WhatsApp & Turn-by-Turn Route are ready.'
                                  : _isWhatsAppUnlocked
                                      ? 'WhatsApp: ${_unlockedPhoneNumber ?? "Contact Available"}'
                                      : _isLocationUnlocked
                                          ? 'Google Maps navigation is ready.'
                                          : (_myWhatsAppConsent || _myLocationConsent)
                                              ? 'Waiting for ${_displayRecipient.name}\'s consent ⏳'
                                              : 'Mutual consent is required to share number & route.',
                              style: TextStyle(
                                fontSize: 11,
                                color: (_isWhatsAppUnlocked || _isLocationUnlocked)
                                    ? Colors.greenAccent
                                    : (_myWhatsAppConsent || _myLocationConsent)
                                        ? Colors.amber
                                        : Colors.tealAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isConsentLoading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.tealAccent),
                        )
                      else if (!_isWhatsAppUnlocked && !_isLocationUnlocked)
                        ElevatedButton.icon(
                          onPressed: _openSafeShareDialog,
                          icon: const Icon(Icons.lock_open, size: 14),
                          label: Text(
                            (_myWhatsAppConsent || _myLocationConsent) ? 'Edit 🔒' : 'Share 🔒',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_myWhatsAppConsent || _myLocationConsent)
                                ? Colors.amber.shade800
                                : const Color(0xFF00BFA5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                  if (_isWhatsAppUnlocked || _isLocationUnlocked) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_isWhatsAppUnlocked)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _launchWhatsAppChat,
                              icon: const Icon(Icons.chat, size: 14),
                              label: const Text(
                                '💬 Chat on WhatsApp',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        if (_isWhatsAppUnlocked && _isLocationUnlocked)
                          const SizedBox(width: 8),
                        if (_isLocationUnlocked)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _launchGoogleMapsRoute,
                              icon: const Icon(Icons.navigation, size: 14),
                              label: const Text(
                                '📍 Open Route in Google Maps',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Manage Sharing',
                          icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _openSafeShareDialog,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Messages List View
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryColor, size: 36),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Say Hi to ${_displayRecipient.name}! ✨',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Break the ice with a ready-to-tap conversation starter:',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 16),

                            // 4-Action Icebreaker Starter Chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildIcebreakerChip('☕ Chai date ke liye kab chalein?'),
                                _buildIcebreakerChip('🎶 Aajkal kaun sa gaana loop pe chal raha hai?'),
                                _buildIcebreakerChip('🌴 Shaam ko ghoomne ki best jagah kaun si hai?'),
                                _buildIcebreakerChip('🎬 Koi achhi movie recommend karo!'),
                                _buildIcebreakerChip('✨ Weekend ka kya plan hai?'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _sendMessage(text: 'Hi 👋 Great to match with you!'),
                              icon: const Icon(Icons.waving_hand, size: 16),
                              label: const Text('Send Quick Hi 👋', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    cacheExtent: 500,
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

  Widget _buildIcebreakerChip(String text) {
    return ActionChip(
      backgroundColor: AppTheme.surfaceColor,
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onPressed: () => _sendMessage(text: text),
    );
  }
}
