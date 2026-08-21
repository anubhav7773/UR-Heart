import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/services/security_service.dart';
import '../../core/ads/ad_manager.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_view_dialog.dart';
import '../subscription/subscription_sheet.dart';
import 'native_ad_card_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/app_update_service.dart';
import 'visitors_sheet.dart';

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
  int _visitorCount = 0;
  bool _isClaimingReward = false;

  // Voice Bio Playback State
  late final AudioPlayer _feedAudioPlayer;
  String? _playingVoiceBioUrl;

  // Discovery Preference Filters State
  String _genderPref = 'everyone';
  RangeValues _ageRange = const RangeValues(18, 50);
  static const double _feedRadiusKm = 500.0;

  @override
  void initState() {
    super.initState();
    _feedAudioPlayer = AudioPlayer();
    _feedAudioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingVoiceBioUrl = null);
    });
    _enableScreenshotProtection();
    AdManager.instance.loadRewardedAd();
    _loadFeed();
    _fetchVisitorCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.instance.checkForUpdate(context);
      }
    });
  }

  Future<void> _fetchVisitorCount() async {
    try {
      final res = await ApiClient.instance.getVisitors(limit: 1);
      if (res.data != null && res.data['data'] != null) {
        final total = (res.data['data']['total_count'] as num?)?.toInt() ?? 0;
        if (mounted) setState(() => _visitorCount = total);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _feedAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _enableScreenshotProtection() async {
    await WindowSecurityService.syncFromStorage();
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

    // Stop active voice bio audio when swiping cards
    try {
      if (_playingVoiceBioUrl != null) {
        await _feedAudioPlayer.stop();
        setState(() => _playingVoiceBioUrl = null);
      }
    } catch (_) {}

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

  Future<void> _claimRewardedSwipes() async {
    setState(() => _isClaimingReward = true);
    AdManager.instance.showRewardedAd(
      onRewardEarned: () async {
        try {
          final res = await ApiClient.instance.claimAdReward(rewardType: 'swipes');
          if (mounted) {
            final data = res.data?['data'];
            final int remaining = data?['remaining_ad_claims_today'] ?? 2;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 +5 Free Swipes Earned! ($remaining video claims remaining today)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            _loadFeed();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reward claim notice: ${e.toString()}')),
            );
          }
        } finally {
          if (mounted) setState(() => _isClaimingReward = false);
        }
      },
      onFailed: () {
        if (mounted) {
          setState(() => _isClaimingReward = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rewarded ad is loading or unavailable. Please try again in a few seconds.'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
      },
    );
  }

  void _showEarnSwipesRewardSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_outlined, color: AppTheme.primaryColor, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'Need More Swipes?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Watch a short sponsored video to get 5 free swipes instantly, or boost your profile for 10x visibility.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Option 1: Watch Rewarded Ad (Free +5 Swipes)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
                ),
                child: Material(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.play_circle_outline, color: Colors.greenAccent, size: 24),
                    ),
                    title: const Text('Watch Short Video (+5 Free Swipes)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Takes 15-30 seconds • Max 3/day', style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 12)),
                    trailing: ElevatedButton(
                      onPressed: _isClaimingReward
                          ? null
                          : () {
                              Navigator.pop(context);
                              _claimRewardedSwipes();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Watch', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Super Boost (₹29) or VIP Pro (₹99)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.35)),
                ),
                child: Material(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_outlined, color: AppTheme.secondaryColor, size: 24),
                    ),
                    title: const Text('Super Boost (₹29) & VIP Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('10x feed priority & unlimited swipes', style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 12)),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const SubscriptionSheet(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDirectDmAction(String targetUserId, String name) async {
    try {
      final passRes = await ApiClient.instance.dio.get('/payments/active-pass');
      final passData = passRes.data?['data'];
      final bool isDirectDmActive = passData?['is_direct_dm_active'] == true;

      if (!isDirectDmActive) {
        if (!mounted) return;
        // User does not have an active Direct DM pass -> Show Monetization Sheet
        final upgraded = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const SubscriptionSheet(initialPlanType: 'direct_dm'),
        );
        
        // If sheet was dismissed without purchase, stop here cleanly
        if (upgraded != true) return;

        // Confirm pass activation after purchase before opening composer
        final verifyRes = await ApiClient.instance.dio.get('/payments/active-pass');
        final verifyData = verifyRes.data?['data'];
        if (verifyData?['is_direct_dm_active'] != true) return;
      }

      if (!mounted) return;
      _showDirectDmComposer(targetUserId, name);
    } catch (e) {
      debugPrint('[DIRECT_DM_ACTION_ERROR] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to verify Direct DM status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showDirectDmComposer(String targetUserId, String name) {
    final textController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.grey[950],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ Direct DM to $name',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Instant message delivery without waiting for a mutual match.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                maxLength: 250,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your message to $name...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: isSending
                  ? null
                  : () async {
                      final msg = textController.text.trim();
                      if (msg.isEmpty) return;
                      setDlgState(() => isSending = true);
                      try {
                        await ApiClient.instance.sendDirectDm(
                          targetUserId: targetUserId,
                          message: msg,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚡ Direct DM sent to $name!'),
                            backgroundColor: Colors.cyan[700],
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        setDlgState(() => isSending = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to send Direct DM: ${e.toString()}')),
                        );
                      }
                    },
              icon: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 16),
              label: const Text('Send DM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
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
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        memCacheWidth: 180,
                        memCacheHeight: 180,
                        maxWidthDiskCache: 360,
                        maxHeightDiskCache: 360,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.person, size: 48, color: Colors.grey),
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
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep Swiping', style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 14)),
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
        voiceBioUrl: profile['voice_bio_url'] as String?,
        voiceBioDurationSeconds: (profile['voice_bio_duration_seconds'] as num?)?.toInt() ?? 15,
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
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('UR Heart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
            tooltip: 'Filter Preferences',
            onPressed: _showFilterBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppTheme.secondaryColor),
            tooltip: 'Earn Free Swipes / Super Boost',
            onPressed: _showEarnSwipesRewardSheet,
          ),
          // Profile Visitors / Ghost Passer Action Button
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () => VisitorsSheet.show(
                  context: context,
                  onVisitorsUpdated: _fetchVisitorCount,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _visitorCount > 0
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _visitorCount > 0
                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                          : AppTheme.cardBorderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: _visitorCount > 0
                            ? AppTheme.primaryColor
                            : AppTheme.mutedTextColor,
                      ),
                      if (_visitorCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$_visitorCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0, left: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorderColor),
                ),
                child: Text(
                  'Skips: $_persistentSkipCount/20',
                  style: const TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.w600),
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
                            ? RepaintBoundary(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: AppTheme.surfaceColor,
                                    border: Border.all(color: AppTheme.cardBorderColor),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Cached Network Image with Error and Loading Fallback Placeholders
                                      if (imageUrl != null && imageUrl.isNotEmpty)
                                        GestureDetector(
                                          onTap: () => _showProfileViewer(Map<String, dynamic>.from(profile as Map)),
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            memCacheWidth: 450,
                                            memCacheHeight: 600,
                                            maxWidthDiskCache: 800,
                                            maxHeightDiskCache: 1200,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: AppTheme.surfaceColor,
                                              child: const Center(
                                                child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) {
                                              return Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(Icons.person, size: 100, color: AppTheme.mutedTextColor),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                            else
                              Container(
                                color: AppTheme.surfaceColor,
                                child: const Center(
                                  child: Icon(Icons.person, size: 100, color: AppTheme.mutedTextColor),
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
                                        color: AppTheme.surfaceColor.withValues(alpha: 0.90),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.verifiedBlue, width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified, color: AppTheme.verifiedBlue, size: 16),
                                          SizedBox(width: 4),
                                          Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor.withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.cardBorderColor),
                                      ),
                                      child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                                    ),
                                    color: AppTheme.surfaceColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: AppTheme.cardBorderColor),
                                    ),
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
                                            Icon(Icons.report_outlined, color: AppTheme.secondaryColor, size: 18),
                                            SizedBox(width: 8),
                                            Text('Report Profile', style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'block',
                                        child: Row(
                                          children: [
                                            Icon(Icons.block_outlined, color: Colors.redAccent, size: 18),
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
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xEE0D0E15),
                                      Color(0x990D0E15),
                                      Colors.transparent,
                                    ],
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
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (isVerified) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.verified, color: AppTheme.verifiedBlue, size: 22),
                                        ],
                                        if (profile['is_boosted'] == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.bolt, color: Colors.white, size: 12),
                                                SizedBox(width: 2),
                                                Text(
                                                  'BOOSTED',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // Micro-Radius Distance & Landmark Pill Chip
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceColor.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.cardBorderColor),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.secondaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                distanceLabel,
                                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Voice Bio Audio Pill Chip
                                        if (profile['voice_bio_url'] != null && (profile['voice_bio_url'] as String).isNotEmpty)
                                          GestureDetector(
                                            onTap: () async {
                                              final url = profile['voice_bio_url'] as String;
                                              if (_playingVoiceBioUrl == url) {
                                                await _feedAudioPlayer.stop();
                                                setState(() => _playingVoiceBioUrl = null);
                                              } else {
                                                await _feedAudioPlayer.play(UrlSource(url));
                                                setState(() => _playingVoiceBioUrl = url);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: _playingVoiceBioUrl == profile['voice_bio_url']
                                                    ? AppTheme.primaryColor.withValues(alpha: 0.25)
                                                    : AppTheme.surfaceColor.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: _playingVoiceBioUrl == profile['voice_bio_url']
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.cardBorderColor,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _playingVoiceBioUrl == profile['voice_bio_url']
                                                        ? Icons.pause_circle_outline
                                                        : Icons.play_circle_outline,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _playingVoiceBioUrl == profile['voice_bio_url']
                                                        ? 'Playing Voice'
                                                        : 'Voice Intro (0:${(profile['voice_bio_duration_seconds'] ?? 15).toString().padLeft(2, '0')})',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
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
                      ),
                    )
                  : Container()))
                    : Center(
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.cardBorderColor),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.favorite_border_rounded, size: 44, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No members nearby right now',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "You've seen all active profiles in your current radius. Earn more swipes or boost your visibility!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppTheme.mutedTextColor),
                                ),
                                const SizedBox(height: 20),

                                // Action 1: Watch Rewarded Video for Free Swipes
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
                                  ),
                                  child: Material(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      onTap: _isClaimingReward ? null : _claimRewardedSwipes,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.play_circle_outline, color: Colors.greenAccent, size: 22),
                                      ),
                                      title: Text(
                                        _isClaimingReward ? 'Loading Video...' : 'Watch video (+5 free swipes)',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedTextColor, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Action 2: Super Boost (₹29) / VIP Pro
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.35)),
                                  ),
                                  child: Material(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => const SubscriptionSheet(),
                                        );
                                      },
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.bolt_outlined, color: AppTheme.secondaryColor, size: 22),
                                      ),
                                      title: const Text(
                                        'Super Boost Profile (₹29)',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedTextColor, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Action 3: Refresh Feed
                                TextButton.icon(
                                  onPressed: _loadFeed,
                                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.mutedTextColor, size: 18),
                                  label: const Text('Refresh Discovery Feed', style: TextStyle(color: AppTheme.mutedTextColor, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // 4-Button Action Deck (Reject / Like / Super DM / Regular DM)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Reject (Cross)
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: 'btn_reject_deck',
                      onPressed: () => _handleSwipeAction('reject'),
                      backgroundColor: AppTheme.surfaceColor,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 26),
                    ),
                  ),

                  // 2. Like (Heart)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FloatingActionButton.large(
                      heroTag: 'btn_like_deck',
                      onPressed: () => _handleSwipeAction('like'),
                      backgroundColor: AppTheme.primaryColor,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 38),
                    ),
                  ),

                  // 3. Send Direct DM (₹49) Pass Button
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: 'btn_direct_dm_deck',
                      onPressed: () => _handleDirectDmAction(targetUserId, firstName),
                      backgroundColor: AppTheme.surfaceColor,
                      shape: const CircleBorder(
                        side: BorderSide(color: AppTheme.secondaryColor, width: 1.5),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: AppTheme.secondaryColor, size: 26),
                    ),
                  ),

                  // 4. DM (Direct Message)
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: 'btn_dm_deck',
                      onPressed: () => _handleSwipeAction('dm'),
                      backgroundColor: AppTheme.surfaceColor,
                      shape: const CircleBorder(
                        side: BorderSide(color: AppTheme.cardBorderColor, width: 1),
                      ),
                      child: const Icon(Icons.send_rounded, color: AppTheme.mutedTextColor, size: 22),
                    ),
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
