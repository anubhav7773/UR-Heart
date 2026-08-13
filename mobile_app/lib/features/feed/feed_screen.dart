import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../chat/chat_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isLoading = true;
  List<dynamic> _cards = [];
  int _currentIndex = 0;
  int _persistentSkipCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.getMatchesFeed(limit: 10);
      if (response.data != null && response.data['data'] != null) {
        final cardsList = response.data['data']['cards'] as List<dynamic>? ?? [];
        setState(() {
          _cards = cardsList;
          _currentIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feed notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSwipeAction(String action) async {
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;

    final currentCard = _cards[_currentIndex];
    final String? targetUserId = currentCard['profile']?['user_id'];
    if (targetUserId == null) {
      setState(() => _currentIndex++);
      return;
    }

    setState(() {
      _currentIndex++;
    });

    try {
      final response = await ApiClient.instance.postMatchesSwipe(
        targetUserId: targetUserId,
        action: action,
      );

      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        final bool isMatch = data['is_match'] ?? false;
        final bool triggerAd = data['trigger_interstitial_ad'] ?? false;
        final int skipCount = data['persistent_skip_count'] ?? 0;

        setState(() {
          _persistentSkipCount = skipCount;
        });
        await StorageManager.instance.saveSkipCount(skipCount);

        if (isMatch && mounted) {
          _showMatchDialog();
        }

        if (triggerAd && mounted) {
          _showInterstitialAdDialog();
        }
      }
    } catch (e) {
      // Background action processing
    }
  }

  Future<void> _handleSendChaiInvite(String targetUserId, String name) async {
    try {
      await ApiClient.instance.sendChaiInvite(receiverId: targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('☕ Sent ₹9 Chai Invite to $name!'),
          backgroundColor: Colors.amber[800],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send Chai Invite: ${e.toString()}')),
      );
    }
  }

  void _showMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Color(0xFFE91E63), size: 30),
            SizedBox(width: 10),
            Text('It\'s a Match!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'You both liked each other! You can now start chatting.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Swiping', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConversationsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
            child: const Text('Send Message', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInterstitialAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.ondemand_video, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Sponsored Video Ad', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_outline, size: 60, color: Colors.amber),
                    SizedBox(height: 12),
                    Text(
                      '20-Skip Interstitial Video Ad (20s)\nUpgrade to ₹99/mo for zero ads',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip Ad', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
      );
    }

    final bool hasCards = _currentIndex < _cards.length;
    final currentCard = hasCards ? _cards[_currentIndex] : null;
    final profile = currentCard?['profile'];
    final photosList = profile != null ? (profile['photos'] as List<dynamic>?) : null;
    final String? imageUrl = (photosList != null && photosList.isNotEmpty) ? photosList.first as String? : null;
    final String targetUserId = profile?['user_id'] ?? 'b1febc88-1c0b-4ef8-bb6d-6bb9bd380b22';
    final String firstName = profile?['first_name'] ?? 'Priya';
    final bool isVerifiedLocal = profile?['is_verified_local'] ?? true;
    final String distanceLabel = profile?['distance_label'] ?? 'Within 2 km • Near Saket College area';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('RuralHeart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConversationsScreen()),
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Text(
                  'Skips: $_persistentSkipCount/20',
                  style: const TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: hasCards && profile != null
                    ? Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.grey[900],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Network Image with Error and Loading Fallback Placeholders
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[900],
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.grey[850]!, Colors.grey[900]!],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.person, size: 100, color: Colors.white24),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(Icons.person, size: 100, color: Colors.white24),
                                ),
                              ),

                            // Top Left "☕ Free for Chai" Active Badge
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('☕', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Free for Chai',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Top Right "Verified Local Resident" Safety Badge
                            if (isVerifiedLocal)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green[800]!.withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.greenAccent, width: 1),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Verified Local Resident',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Profile Details Gradient Overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(20.0),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xF0000000), Colors.transparent],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${profile['first_name']}, ${profile['age']}',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.verified, color: Colors.blue, size: 22),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // Micro-Radius Distance & Landmark Pill Chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[700]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            distanceLabel,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      profile['bio'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.style, size: 60, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No More Profiles Nearby',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadFeed,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                              child: const Text('Refresh Feed', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // 4-Button Action Deck (Reject / Like / Chai Invite / DM)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Reject (Cross)
                  FloatingActionButton(
                    heroTag: 'btn_reject_deck',
                    onPressed: () => _handleSwipeAction('reject'),
                    backgroundColor: Colors.grey[900],
                    shape: const CircleBorder(),
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 28),
                  ),

                  // 2. Like (Heart)
                  FloatingActionButton.large(
                    heroTag: 'btn_like_deck',
                    onPressed: () => _handleSwipeAction('like'),
                    backgroundColor: const Color(0xFFE91E63),
                    shape: const CircleBorder(),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 40),
                  ),

                  // 3. Send ₹9 Chai Invite Button
                  FloatingActionButton(
                    heroTag: 'btn_chai_invite_deck',
                    onPressed: () => _handleSendChaiInvite(targetUserId, firstName),
                    backgroundColor: Colors.amber[800],
                    shape: const CircleBorder(),
                    child: const Text('☕', style: TextStyle(fontSize: 22)),
                  ),

                  // 4. DM (Direct Message)
                  FloatingActionButton(
                    heroTag: 'btn_dm_deck',
                    onPressed: () => _handleSwipeAction('dm'),
                    backgroundColor: Colors.grey[900],
                    shape: const CircleBorder(),
                    child: const Icon(Icons.send_rounded, color: Colors.amber, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
