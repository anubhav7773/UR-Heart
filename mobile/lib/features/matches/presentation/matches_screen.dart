import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';
import 'package:ur_heart/features/matches/data/matches_repository.dart';

/// Screen: Matches & Active Conversations
class MatchesScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onExploreTap;

  const MatchesScreen({
    super.key,
    this.lang = 'en',
    this.onExploreTap,
  });

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SecureScreenMixin {
  final MatchesRepository _repo = MatchesRepository();
  List<MatchItemModel> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    final list = await _repo.getMatches();
    if (mounted) {
      setState(() {
        _matches = list;
        _isLoading = false;
      });
    }
  }

  void _openChat(MatchItemModel match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          lang: widget.lang,
          matchId: match.matchId,
          participantName: match.partnerName,
          participantId: match.partnerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        backgroundColor: URHeartColors.cardSurface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [URHeartColors.brandPrimary, URHeartColors.accentGold],
                ),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Matches & Chats',
                  style: TextStyle(
                    color: URHeartColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_matches.length} Connected Profiles',
                  style: const TextStyle(
                    color: URHeartColors.brandSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: URHeartColors.textSecondary),
            onPressed: _loadMatches,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: URHeartColors.brandPrimary),
            )
          : RefreshIndicator(
              onRefresh: _loadMatches,
              color: URHeartColors.brandPrimary,
              child: _matches.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // New Matches Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                const Text(
                                  'New Mutual Matches',
                                  style: TextStyle(
                                    color: URHeartColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: URHeartColors.brandPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_matches.length}',
                                    style: const TextStyle(
                                      color: URHeartColors.brandPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 105,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: _matches.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                final match = _matches[index];
                                return _buildNewMatchAvatar(match);
                              },
                            ),
                          ),

                          const SizedBox(height: 20),
                          // Conversations Section
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text('💬', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  'Direct Messages & Encrypted Chat',
                                  style: TextStyle(
                                    color: URHeartColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _matches.length,
                            separatorBuilder: (_, __) => const Divider(
                              color: URHeartColors.surfaceRaised,
                              height: 1,
                              indent: 76,
                            ),
                            itemBuilder: (context, index) {
                              final match = _matches[index];
                              return _buildConversationTile(match);
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildNewMatchAvatar(MatchItemModel match) {
    return GestureDetector(
      onTap: () => _openChat(match),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[URHeartColors.brandPrimary, URHeartColors.brandSecondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: URHeartColors.brandPrimary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: URHeartColors.surfaceRaised,
              backgroundImage: CachedNetworkImageProvider(match.partnerPhotoUrl),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              match.partnerName.split(' ').first,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: URHeartColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(MatchItemModel match) {
    final preview = match.lastMessage ?? 'Say hello! Tap to start conversation 👋';
    return InkWell(
      onTap: () => _openChat(match),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with online green dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: URHeartColors.surfaceRaised,
                  backgroundImage: CachedNetworkImageProvider(match.partnerPhotoUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: URHeartColors.statusSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: URHeartColors.canvasBackground, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        match.partnerName,
                        style: const TextStyle(
                          color: URHeartColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: URHeartColors.brandSecondary, size: 15),
                      const Spacer(),
                      Text(
                        '${match.createdAt.hour.toString().padLeft(2, '0')}:${match.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: URHeartColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: URHeartColors.textMuted, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        match.partnerCity,
                        style: const TextStyle(color: URHeartColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: match.lastMessage != null ? URHeartColors.textPrimary : URHeartColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // WhatsApp Reveal Status Pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: match.whatsappUnlocked
                              ? const Color(0xFF25D366).withValues(alpha: 0.15)
                              : URHeartColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: match.whatsappUnlocked
                                ? const Color(0xFF25D366).withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              match.whatsappUnlocked ? '💬 WhatsApp Unlocked' : '🔒 3-Ad Reveal',
                              style: TextStyle(
                                color: match.whatsappUnlocked
                                    ? const Color(0xFF25D366)
                                    : URHeartColors.accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, size: 64, color: URHeartColors.brandPrimary),
            const SizedBox(height: 16),
            const Text(
              'No Matches Yet',
              style: TextStyle(
                color: URHeartColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Swipe right on candidates in the Discovery Feed to create mutual matches and unlock private chat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: URHeartColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onExploreTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: URHeartColors.brandPrimary,
                shape: const RoundedRectangleBorder(borderRadius: URHeartTheme.radiusPill),
              ),
              icon: const Icon(Icons.explore_rounded, color: Colors.white),
              label: const Text('Go to Discovery Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
