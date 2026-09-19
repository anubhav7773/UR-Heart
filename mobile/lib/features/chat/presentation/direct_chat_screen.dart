import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/config/env_config.dart';
import '../../../core/network/api_client.dart';
import '../data/chat_repository.dart';

class DirectChatScreen extends StatefulWidget {
  final String matchId;
  final String partnerId;
  final String partnerName;
  final String? partnerPhoto;

  const DirectChatScreen({
    super.key,
    required this.matchId,
    String? partnerId,
    String? partnerName,
    String? recipientId,
    String? recipientName,
    this.partnerPhoto,
  })  : partnerId = partnerId ?? recipientId ?? '',
        partnerName = partnerName ?? recipientName ?? 'Anonymous';

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final ChatRepository _repository = ChatRepository();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isLoadingHistory = true;
  List<ChatMessageModel> _messages = [];
  String _currentUid = "";

  @override
  void initState() {
    super.initState();
    try {
      _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    } catch (_) {
      _currentUid = "";
    }
    _initChat().then((_) {
      // Focus room and mark unread messages as read
      _focusRoom();
      _sendMarkRead();
    });
  }

  void _focusRoom() {
    if (_wsChannel != null && widget.matchId.isNotEmpty) {
      try {
        _wsChannel?.sink.add(jsonEncode({
          "action": "focus_room",
          "match_id": widget.matchId,
        }));
      } catch (_) {}
    }
  }

  void _sendMarkRead() {
    if (_wsChannel != null && widget.matchId.isNotEmpty) {
      try {
        _wsChannel?.sink.add(jsonEncode({
          "action": "mark_read",
          "match_id": widget.matchId,
          "sender_id": widget.partnerId,
        }));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    // Notify backend that user has left the screen
    try {
      _wsChannel?.sink.add(jsonEncode({
        "action": "blur_room",
      }));
    } catch (_) {}

    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    // 1. Fetch Chat History
    try {
      final history = await _repository.fetchHistory(widget.matchId);
      if (mounted) {
        setState(() {
          _messages = history;
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }

    // 2. Connect to WebSocket
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;

      final baseWs = EnvConfig.wsBaseUrl.isNotEmpty
          ? EnvConfig.wsBaseUrl
          : 'wss://ur-heart.onrender.com';
      final wsUrl = Uri.parse('$baseWs/ws/chat?token=$idToken');
      _wsChannel = WebSocketChannel.connect(wsUrl);
      _focusRoom();
      _sendMarkRead();

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            final event = json['event'] ?? json['type'];

            if (event == 'message_delivered') {
              final msgId = json['message_id']?.toString() ?? json['msg_id']?.toString();
              if (mounted) {
                setState(() {
                  final idx = _messages.indexWhere((m) => m.id == msgId);
                  if (idx != -1) {
                    _messages[idx].isDelivered = true;
                  }
                });
              }
            } else if (event == 'messages_read') {
              // Partner opened chat -> update all sent messages to read (double blue ticks)
              if (mounted) {
                setState(() {
                  for (var m in _messages) {
                    final bool isMe = (m.senderId == _currentUid) || (widget.partnerId.isNotEmpty && m.senderId != widget.partnerId);
                    if (isMe) {
                      m.isDelivered = true;
                      m.isRead = true;
                    }
                  }
                });
              }
            } else if (event == 'new_message' || event == 'incoming_message') {
              final newMsg = ChatMessageModel.fromJson(json);
              if (newMsg.matchId == widget.matchId) {
                if (mounted) {
                  setState(() {
                    final existingIdx = _messages.indexWhere(
                      (m) => m.id == newMsg.id || (m.id.startsWith('opt_') && m.content == newMsg.content),
                    );
                    if (existingIdx != -1) {
                      _messages[existingIdx] = newMsg;
                    } else {
                      _messages.add(newMsg);
                    }
                  });
                  // Send immediate mark_read ack
                  _sendMarkRead();
                  _scrollToBottom();
                }
              }
            } else if (event == 'anti_leak_violation' || event == 'error') {
              final reason = json['message'] ?? json['detail'] ?? "Sharing contacts or off-platform handles is prohibited.";
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("⚠️ $reason"),
                    backgroundColor: const Color(0xFFFF334B),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          } catch (_) {}
        },
        onError: (err) {
          // Reconnect logic if connection drops
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectWebSocket();
          });
        },
      );
    } catch (_) {}
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _wsChannel == null) return;

    final outgoingPayload = {
      "type": "message",
      "match_id": widget.matchId,
      "recipient_id": widget.partnerId,
      "content": text,
    };

    // Send over WebSocket
    _wsChannel!.sink.add(jsonEncode(outgoingPayload));

    // Optimistic local update
    final optimisticMsg = ChatMessageModel(
      id: "opt_${DateTime.now().millisecondsSinceEpoch}",
      matchId: widget.matchId,
      senderId: _currentUid,
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimisticMsg);
      _msgController.clear();
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReportAndBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Report & Block Sender",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure? This sender will be blocked immediately and their direct messaging privilege will be frozen to prevent harassment.",
          style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF334B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeReportAndBlock();
            },
            child: const Text("Block & Auto-Ban", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeReportAndBlock() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      await dio.post(
        '/api/v1/safety/report-and-block',
        data: {
          'reported_user_id': widget.partnerId,
          'report_type': 'direct_dm_abuse',
          'message_snippet': _messages.isNotEmpty ? _messages.last.content : '',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ User reported and blocked. Direct DM privileges suspended."),
            backgroundColor: Color(0xFF06D6A0),
          ),
        );
        Navigator.of(context).pop(); // Exit chat screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFFF334B)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color brandCrimson = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161D),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF22222C),
              backgroundImage: widget.partnerPhoto != null && widget.partnerPhoto!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.partnerPhoto!)
                  : null,
              child: widget.partnerPhoto == null || widget.partnerPhoto!.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "End-to-End Monitored • Safe Chat",
                    style: TextStyle(color: Color(0xFF06D6A0), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF16161D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'report_block') {
                _showReportAndBlockDialog(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report_block',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFFF334B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Report & Block Sender",
                      style: TextStyle(color: Color(0xFFFF334B), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Anti-leak statutory notice banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1B1B24),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF08D9D6), size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sharing phone numbers, WhatsApp handles or off-platform links is prohibited.",
                    style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Message Bubbles List
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: brandCrimson))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final m = _messages[idx];
                      final bool isMe = (m.senderId == _currentUid) || (m.senderId != widget.partnerId);
                      return _buildMessageBubble(m, isMe);
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
              left: 12,
              right: 12,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF16161D),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF22222C),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: "Type a romantic message...",
                        hintStyle: TextStyle(color: Color(0xFF636375), fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: brandCrimson,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFF2E63) : const Color(0xFF22222C),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.content,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(m.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : const Color(0xFFA0A0B2),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildTickIndicator(m),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickIndicator(ChatMessageModel m) {
    if (m.isRead) {
      // 3. Stage: Double Blue Tick
      return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF00B2FF));
    } else if (m.isDelivered) {
      // 2. Stage: Double Gray Tick
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white60);
    } else {
      // 1. Stage: Single Gray Tick
      return const Icon(Icons.done_rounded, size: 14, color: Colors.white60);
    }
  }
}
