import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/location_service.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_view_dialog.dart';
import 'native_ad_card_widget.dart';

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

  // Discovery Preference Filters State
  String _genderPref = 'everyone';
  RangeValues _ageRange = const RangeValues(18, 50);
  static const double _feedRadiusKm = 500.0;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _loadFeed();
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
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

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final pos = await LocationService.instance.getCurrentLocation();

      final response = await ApiClient.instance.getMatchesFeed(
        limit: 10,
        genderPreference: _genderPref,
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        maxDistanceKm: _feedRadiusKm,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
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
          final String matchId = (data['match_id'] ?? '').toString();
          final profileMap = currentCard['profile'] as Map<String, dynamic>? ?? {};
          _showMatchDialog(matchId: matchId, matchedProfile: profileMap);
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

  void _showFilterBottomSheet() {
    String tempGender = _genderPref;
    RangeValues tempAge = _ageRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, color: Color(0xFFE91E63)),
                          SizedBox(width: 8),
                          Text(
                            'Discovery Preferences',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Gender Preference Filter
                  const Text('Interested In', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Everyone 👥'),
                        selected: tempGender == 'everyone',
                        selectedColor: const Color(0xFFE91E63),
                        onSelected: (sel) => setModalState(() => tempGender = 'everyone'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Women 👧'),
                        selected: tempGender == 'female',
                        selectedColor: const Color(0xFFE91E63),
                        onSelected: (sel) => setModalState(() => tempGender = 'female'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Men 👦'),
                        selected: tempGender == 'male',
                        selectedColor: const Color(0xFFE91E63),
                        onSelected: (sel) => setModalState(() => tempGender = 'male'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Age Range Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Age Range', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      Text(
                        '${tempAge.start.round()} - ${tempAge.end.round()} yrs',
                        style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: tempAge,
                    min: 18,
                    max: 60,
                    divisions: 42,
                    activeColor: const Color(0xFFE91E63),
                    inactiveColor: Colors.grey[800],
                    onChanged: (vals) => setModalState(() => tempAge = vals),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _genderPref = tempGender;
                          _ageRange = tempAge;
                        });
                        Navigator.pop(context);
                        _loadFeed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReportDialog(String userId, String userName) {
    String selectedReason = 'Inappropriate Content';
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: Colors.amber),
              const SizedBox(width: 10),
              Text('Report $userName', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
                dropdownColor: Colors.grey[850],
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
                  fillColor: Colors.grey[800],
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
                    reportedUserId: userId,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. Thank you for helping keep RuralHeart safe.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Notice: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text('Block $userName?', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'They will no longer be able to see your profile or send you messages on RuralHeart.',
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
              Navigator.pop(context);
              try {
                await ApiClient.instance.blockUser(blockedUserId: userId);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Blocked $userName successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                _loadFeed();
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

  void _showMatchDialog({required String matchId, required Map<String, dynamic> matchedProfile}) {
    final String targetName = (matchedProfile['full_name'] ?? matchedProfile['first_name'] ?? 'Your Match').toString();
    final String targetUserId = (matchedProfile['user_id'] ?? '').toString();
    final photos = (matchedProfile['photos'] as List<dynamic>? ?? []);
    final String photoUrl = photos.isNotEmpty ? photos.first.toString() : '';
    final bool isVerified = matchedProfile['is_verified'] == true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[950],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
        ),
        title: const Column(
          children: [
            Icon(Icons.favorite, color: Color(0xFFE91E63), size: 48),
            SizedBox(height: 8),
            Text(
              'It\'s a Match! 🎉',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE91E63), width: 3),
              ),
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48, color: Colors.grey),
                      )
                    : const Icon(Icons.person, size: 48, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  targetName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: Colors.blue, size: 18),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You and $targetName liked each other! Start the conversation right now.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (matchId.isNotEmpty && targetUserId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            matchId: matchId,
                            recipientUser: ChatRecipient(
                              id: targetUserId,
                              name: targetName,
                              avatarUrl: photoUrl,
                              isVerified: isVerified,
                            ),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConversationsScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble, size: 18),
                  label: const Text('Send Message 💬', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Swiping', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProfileViewer(Map<String, dynamic> profile) {
    final photos = (profile['photos'] as List<dynamic>? ?? [])
        .map((photo) => photo.toString())
        .where((photo) => photo.isNotEmpty)
        .take(5)
        .toList();
    if (photos.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => ProfileViewDialog(
        name: (profile['full_name'] ?? profile['first_name'] ?? 'User').toString(),
        age: (profile['age'] as num?)?.toInt() ?? 0,
        distanceLabel: (profile['distance_label'] ?? 'Location unavailable').toString(),
        photos: photos,
        isVerified: profile['is_verified'] == true,
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
    final String cardType = currentCard?['type'] ?? 'profile';
    final profile = currentCard?['profile'];
    final photosList = profile != null ? (profile['photos'] as List<dynamic>?) : null;
    final String? imageUrl = (photosList != null && photosList.isNotEmpty) ? photosList.first as String? : null;
    final String targetUserId = profile?['user_id'] ?? '';
    final String firstName = profile?['first_name'] ?? 'User';
    final bool isVerified = profile?['is_verified'] == true;
    final String distanceLabel = profile?['distance_label'] ?? (profile?['distance_km'] != null ? '${profile!['distance_km']} km away' : 'Nearby');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('UR Heart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFE91E63)),
            onPressed: _showFilterBottomSheet,
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Text(
                  'Skips: $_persistentSkipCount/20',
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
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
                child: hasCards
                    ? (cardType == 'ad_slot'
                        ? NativeAdCardWidget(
                            adUnitId: currentCard?['ad_config']?['ad_unit_id'] ?? 'ca-app-pub-5734148065484801/7497381449',
                          )
                        : (profile != null
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
                              GestureDetector(
                                onTap: () => _showProfileViewer(Map<String, dynamic>.from(profile as Map)),
                                child: Image.network(
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
                                ),
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

                            // Top Right Safety 3-Dots Safety Menu & Verified Badge
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  if (isVerified)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green[800]!.withValues(alpha: 0.90),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.greenAccent, width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 16),
                                          SizedBox(width: 4),
                                          Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                                    ),
                                    color: Colors.grey[900],
                                    onSelected: (val) {
                                      if (val == 'report') {
                                        _showReportDialog(targetUserId, firstName);
                                      } else if (val == 'block') {
                                        _showBlockConfirmDialog(targetUserId, firstName);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'report',
                                        child: Row(
                                          children: [
                                            Icon(Icons.report, color: Colors.amber, size: 18),
                                            SizedBox(width: 8),
                                            Text('Report Profile', style: TextStyle(color: Colors.white)),
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
                                          (profile['age'] != null && (profile['age'] as num) > 0)
                                              ? '${(profile['full_name'] as String?)?.isNotEmpty == true ? profile['full_name'] : (profile['first_name'] ?? 'User')}, ${profile['age']}'
                                              : '${(profile['full_name'] as String?)?.isNotEmpty == true ? profile['full_name'] : (profile['first_name'] ?? 'User')}',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (isVerified) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.verified, color: Colors.blue, size: 22),
                                        ],
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
                    : Container()))
                    : Center(
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.favorite_border_rounded, size: 48, color: Color(0xFFE91E63)),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No members nearby right now! ✨',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "You've seen all active profiles in your current radius.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(height: 20),

                                ElevatedButton.icon(
                                  onPressed: _loadFeed,
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                  label: const Text('Refresh Feed', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    backgroundColor: const Color(0xFFE91E63),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

                  // 3. Send ₹9 Direct Invite Button
                  FloatingActionButton(
                    heroTag: 'btn_direct_invite_deck',
                    onPressed: () => _handleSendChaiInvite(targetUserId, firstName),
                    backgroundColor: Colors.amber[800],
                    shape: const CircleBorder(),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 24),
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
