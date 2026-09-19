import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/core/widgets/insufficient_credits_sheet.dart';
import 'package:ur_heart/core/widgets/luxury_empty_card.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';
import 'package:ur_heart/features/matches/data/matches_repository.dart';
import 'package:ur_heart/features/ads/services/ad_manager.dart';
import 'package:ur_heart/features/wallet/data/wallet_repository.dart';

/// Dual-Tab Screen: Connected Matches & "Second Chance" Missed Connections Tray
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

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin, SecureScreenMixin {
  late TabController _tabController;
  final MatchesRepository _repo = MatchesRepository();
  final WalletRepository _walletRepo = WalletRepository();
  List<MatchItemModel> _matches = [];
  bool _isLoadingMatches = true;

  bool _isLoadingMissed = false;
  List<Map<String, dynamic>> _missedProfiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatches();
    _fetchMissedConnections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoadingMatches = true);
    try {
      final list = await _repo.getMatches();
      if (mounted) {
        setState(() {
          _matches = list;
          _isLoadingMatches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  Future<void> _fetchMissedConnections() async {
    setState(() => _isLoadingMissed = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      final response = await dio.get(
        '/api/v1/swipes/missed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _missedProfiles = List<Map<String, dynamic>>.from(response.data);
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMissed = false);
    }
  }

  Future<void> _executeUnlock(Map<String, dynamic> profile) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      final res = await dio.post(
        '/api/v1/swipes/missed/${profile['user_id']}/unlock-view',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode == 200) {
        setState(() {
          profile['is_unlocked_for_view'] = true;
          profile['bio'] = res.data['bio'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✓ Full profile unlocked for 24 hours!"),
              backgroundColor: Color(0xFF06D6A0),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to unlock: $e"),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      }
    }
  }

  Future<void> _handleUnlockProfile(Map<String, dynamic> profile) async {
    final targetUserId = profile['user_id']?.toString() ?? "missed_profile";

    try {
      final balance = await _walletRepo.fetchBalance();
      if (balance.missedBioPasses > 0) {
        final spent = await _walletRepo.spendCredit(
          rewardType: "missed_bio_pass",
          amount: 1,
          targetId: targetUserId,
        );
        if (spent) {
          await _executeUnlock(profile);
          return;
        }
      }

      // If 0 passes: Present InsufficientCreditsSheet
      if (mounted) {
        InsufficientCreditsSheet.show(
          context,
          actionType: CreditActionType.missedBio,
          targetUserId: targetUserId,
          onCreditAcquired: () async {
            try {
              await _walletRepo.spendCredit(
                rewardType: "missed_bio_pass",
                amount: 1,
                targetId: targetUserId,
              );
            } catch (_) {}
            await _executeUnlock(profile);
          },
        );
      }
    } catch (_) {
      if (mounted) {
        InsufficientCreditsSheet.show(
          context,
          actionType: CreditActionType.missedBio,
          targetUserId: targetUserId,
          onCreditAcquired: () => _executeUnlock(profile),
        );
      }
    }
  }

  Future<void> _executeSendDm(Map<String, dynamic> profile, String text) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      await dio.post(
        '/api/v1/swipes/missed/${profile['user_id']}/send-dm',
        data: {"message": text},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Message sent directly!"),
            backgroundColor: Color(0xFF06D6A0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Send failed: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      }
    }
  }

  void _showDirectDmModal(Map<String, dynamic> profile) {
    final TextEditingController msgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: Color(0xFFFFD166), size: 20),
                const SizedBox(width: 8),
                Text(
                  "Direct DM to ${profile['full_name']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Watch 1 Rewarded Ad (30s) to send an instant direct message without matching (Max 3/day).",
              style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgController,
              maxLines: 3,
              maxLength: 250,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Write a respectful message...",
                hintStyle: const TextStyle(color: Color(0xFF636375)),
                filled: true,
                fillColor: const Color(0xFF22222C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E63),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final text = msgController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);

                  final userId = FirebaseAuth.instance.currentUser?.uid ?? "user_default";

                  // Trigger Rewarded Video Ad
                  final bool shown = AdManager.instance.showRewardedAd(
                    userId: userId,
                    adType: "second_chance_dm",
                    targetId: profile['user_id'],
                    onRewardGranted: () => _executeSendDm(profile, text),
                  );

                  if (!shown) {
                    // In dev/test when real ad is not preloaded, allow sending directly
                    _executeSendDm(profile, text);
                  }
                },
                child: const Text(
                  "Watch Ad & Send Direct DM",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Matches & Connections",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: brandPrimary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFA0A0B2),
          tabs: const [
            Tab(text: "Connected (Matches)"),
            Tab(text: "Second Chance (Missed)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Connected Matches
          _buildConnectedMatchesTab(),

          // TAB 2: Second Chance (Missed Profiles)
          _buildSecondChanceTab(),
        ],
      ),
    );
  }

  Widget _buildConnectedMatchesTab() {
    if (_isLoadingMatches) {
      return const Center(child: CircularProgressIndicator(color: URHeartColors.brandPrimary));
    }

    if (_matches.isEmpty) {
      return LuxuryEmptyCard(
        icon: Icons.favorite_rounded,
        accentColor: const Color(0xFFFF2E63),
        title: "No Mutual Matches Yet",
        description: "When you and another member like each other on Discovery, your mutual match connection will blossom here.",
        actionLabel: "Explore Nearby Profiles →",
        onAction: () {
          if (widget.onExploreTap != null) {
            widget.onExploreTap!();
          } else {
            DefaultTabController.of(context).animateTo(0);
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: URHeartColors.brandPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const Divider(
          color: URHeartColors.surfaceRaised,
          height: 1,
          indent: 76,
        ),
        itemBuilder: (context, index) {
          final match = _matches[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: URHeartColors.surfaceRaised,
              backgroundImage: match.partnerPhotoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(match.partnerPhotoUrl)
                  : null,
              child: match.partnerPhotoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            title: Text(
              match.partnerName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              match.lastMessage ?? "📍 ${match.partnerCity}",
              style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFF2E63), size: 20),
            onTap: () => _openChat(match),
          );
        },
      ),
    );
  }

  Widget _buildSecondChanceTab() {
    if (_isLoadingMissed) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E63)));
    }

    if (_missedProfiles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMissedConnections,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.history, color: Color(0xFFA0A0B2), size: 48),
                  SizedBox(height: 12),
                  Text(
                    "No Missed Profiles",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Profiles you pass on the feed will appear here for 14 days.",
                    style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMissedConnections,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _missedProfiles.length,
        itemBuilder: (ctx, idx) {
          final p = _missedProfiles[idx];
          final bool isUnlocked = p['is_unlocked_for_view'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16161D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                // Profile Avatar Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 70,
                    height: 85,
                    child: p['photo_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: p['photo_url'],
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => BlurHash(hash: p['blur_hash'] ?? "LEHLh[WB2yk8pyoJadR*.7kCMdnj"),
                            errorWidget: (ctx, url, err) => Container(
                              color: const Color(0xFF22222C),
                              child: const Icon(Icons.person, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF22222C),
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details & Unlocked Bio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['full_name'] ?? "UR-Heart User",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "📍 ${p['locality'] ?? p['city'] ?? 'India'}",
                        style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                      ),
                      const SizedBox(height: 4),

                      if (isUnlocked && p['bio'] != null && (p['bio'] as String).isNotEmpty)
                        Text(
                          '"${p['bio']}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF08D9D6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _handleUnlockProfile(p),
                          icon: const Icon(Icons.lock_open, size: 14, color: Color(0xFFFFD166)),
                          label: const Text(
                            "View Bio",
                            style: TextStyle(color: Color(0xFFFFD166), fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),

                // Direct DM Action Button
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFFF2E63)),
                  tooltip: "Send Direct DM",
                  onPressed: () => _showDirectDmModal(p),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
