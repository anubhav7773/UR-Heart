import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../data/chat_repository.dart';
import 'direct_chat_screen.dart';
import '../../../core/widgets/luxury_empty_card.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatRepository _repository = ChatRepository();
  bool _isLoading = true;
  List<MatchConversationModel> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.fetchMatches();
      if (mounted) {
        setState(() => _conversations = data);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color brandCrimson = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Direct Encrypted Chats",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandCrimson))
          : _conversations.isEmpty
              ? LuxuryEmptyCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  accentColor: const Color(0xFF08D9D6),
                  title: "No Conversations Yet",
                  description: "When you swipe right and match with members, your direct conversations will blossom here.",
                  actionLabel: "Explore Nearby Profiles →",
                  onAction: () => DefaultTabController.of(context).animateTo(0),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: brandCrimson,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      // Top Row: New Resonant Matches (Stories / Bubbles)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "New Matches (${_conversations.length})",
                          style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 95,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: _conversations.length,
                          itemBuilder: (ctx, idx) {
                            final c = _conversations[idx];
                            return GestureDetector(
                              onTap: () => _openChat(c),
                              child: Container(
                                width: 72,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF2E63), Color(0xFFFFD166)],
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: const Color(0xFF16161D),
                                        backgroundImage: c.partnerPhoto != null && c.partnerPhoto!.isNotEmpty
                                            ? CachedNetworkImageProvider(c.partnerPhoto!)
                                            : null,
                                        child: c.partnerPhoto == null || c.partnerPhoto!.isEmpty
                                            ? const Icon(Icons.person, color: Colors.grey)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.partnerName.split(" ").first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 24),

                      // Conversations List View
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Recent Messages",
                          style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._conversations.map((c) => _buildConversationTile(c)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildConversationTile(MatchConversationModel c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF22222C),
              backgroundImage: c.partnerPhoto != null && c.partnerPhoto!.isNotEmpty
                  ? CachedNetworkImageProvider(c.partnerPhoto!)
                  : null,
              child: c.partnerPhoto == null || c.partnerPhoto!.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            if (c.whatsappUnlocked)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                  child: const Icon(Icons.phone, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                c.partnerName,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateFormat('hh:mm a').format(c.lastMessageAt),
              style: const TextStyle(color: Color(0xFF636375), fontSize: 11),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            c.lastMessage.isNotEmpty ? c.lastMessage : "Say hi to start connecting ✨",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13),
          ),
        ),
        onTap: () => _openChat(c),
      ),
    );
  }

  void _openChat(MatchConversationModel c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          matchId: c.matchId,
          partnerId: c.partnerId,
          partnerName: c.partnerName,
          partnerPhoto: c.partnerPhoto,
        ),
      ),
    ).then((_) => _loadConversations());
  }
}
