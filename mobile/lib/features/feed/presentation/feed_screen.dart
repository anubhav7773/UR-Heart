import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/core/widgets/insufficient_credits_sheet.dart';
import 'package:ur_heart/features/chat/presentation/chat_room_screen.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';
import 'package:ur_heart/features/wallet/data/wallet_repository.dart';
import 'widgets/radar_sonar_empty_state.dart';

/// Screen 3: Production Discovery Swipe Feed with Real Candidate Profiles & Live Swiping
class FeedScreen extends StatefulWidget {
  final String lang;
  final VoidCallback? onDirectDmTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onPassTap;

  const FeedScreen({
    super.key,
    this.lang = 'en',
    this.onDirectDmTap,
    this.onLikeTap,
    this.onPassTap,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SecureScreenMixin {
  final FeedRepository _feedRepository = FeedRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final WalletRepository _walletRepository = WalletRepository();

  List<CandidateProfileModel> _candidates = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  int _dmTokens = 0;
  int _streakCount = 0;
  String _currentUserCity = '';
  bool _isProcessingSwipe = false;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _feedRepository.getCandidates(),
        _profileRepository.getProfile(),
        _walletRepository.fetchBalance(),
      ]);
      final candidates = results[0] as List<CandidateProfileModel>;
      final profile = results[1] as UserProfileData?;
      final wallet = results[2] as WalletBalanceModel?;

      if (mounted) {
        setState(() {
          _candidates = candidates;
          _currentIndex = 0;
          if (profile != null) {
            _streakCount = profile.streakCount;
            _currentUserCity = profile.city;
          }
          if (wallet != null) {
            _dmTokens = wallet.dmCredits;
          } else if (profile != null) {
            _dmTokens = profile.rewardBalance;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSwipe(String swipeType) async {
    if (_isProcessingSwipe || _currentIndex >= _candidates.length) return;

    final candidate = _candidates[_currentIndex];
    setState(() {
      _isProcessingSwipe = true;
      _currentIndex++;
    });

    try {
      final result = await _feedRepository.submitSwipe(
        targetUserId: candidate.id,
        swipeType: swipeType,
      );

      if (mounted) {
        setState(() {
          if (result.remainingDmTokens != null) {
            _dmTokens = result.remainingDmTokens!;
          }
          _isProcessingSwipe = false;
        });

        if (result.isMatch) {
          _showMatchDialog(candidate, result.matchId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingSwipe = false;
        });
      }
    }
  }

  Future<void> _handleSwipeDismissed(String swipeType, CandidateProfileModel candidate) async {
    setState(() {
      _currentIndex++;
    });

    try {
      final result = await _feedRepository.submitSwipe(
        targetUserId: candidate.id,
        swipeType: swipeType,
      );

      if (result.remainingDmTokens != null && mounted) {
        setState(() {
          _dmTokens = result.remainingDmTokens!;
        });
      }

      if (mounted && result.isMatch) {
        _showMatchDialog(candidate, result.matchId);
      }
    } catch (e) {
      debugPrint('Feed swipe error: $e');
    }
  }

  Future<void> _handleDirectDmAction() async {
    if (_currentIndex >= _candidates.length) return;
    final candidate = _candidates[_currentIndex];

    try {
      final balance = await _walletRepository.fetchBalance();
      if (mounted) {
        setState(() {
          _dmTokens = balance.dmCredits;
        });
      }

      if (balance.dmCredits > 0) {
        final spent = await _walletRepository.spendCredit(
          rewardType: "dm_credit",
          amount: 1,
          targetId: candidate.id,
        );
        if (spent) {
          if (mounted) {
            setState(() {
              _dmTokens = (balance.dmCredits - 1).clamp(0, 9999);
            });
            _openDirectDmComposer(candidate);
          }
        } else {
          if (mounted) {
            _showInsufficientDmSheet(candidate);
          }
        }
      } else {
        if (mounted) {
          _showInsufficientDmSheet(candidate);
        }
      }
    } catch (_) {
      if (_dmTokens > 0) {
        _openDirectDmComposer(candidate);
      } else {
        _showInsufficientDmSheet(candidate);
      }
    }
  }

  void _showInsufficientDmSheet(CandidateProfileModel candidate) {
    InsufficientCreditsSheet.show(
      context,
      actionType: CreditActionType.directDm,
      targetUserId: candidate.id,
      onCreditAcquired: () async {
        try {
          await _walletRepository.spendCredit(
            rewardType: "dm_credit",
            amount: 1,
            targetId: candidate.id,
          );
        } catch (_) {}
        if (mounted) {
          _openDirectDmComposer(candidate);
        }
      },
    );
  }

  void _openDirectDmComposer(CandidateProfileModel candidate) {
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
                const Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 22),
                const SizedBox(width: 8),
                Text(
                  "Direct DM to ${candidate.fullName}",
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
              "Send an instant direct message using your DM credit.",
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
                onPressed: () async {
                  final text = msgController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);
                  await _handleSwipe('direct_dm');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✓ Direct message sent!"),
                        backgroundColor: Color(0xFF06D6A0),
                      ),
                    );
                  }
                },
                child: const Text(
                  "Send Message",
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

  void _showMatchDialog(CandidateProfileModel candidate, String? matchId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: URHeartColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉 It\'s a Match!',
                style: TextStyle(
                  color: URHeartColors.accentGold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You and ${candidate.fullName} liked each other! Break the ice before the spark fades.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: URHeartColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: URHeartColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        lang: widget.lang,
                        matchId: matchId,
                        participantName: candidate.fullName,
                        participantId: candidate.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                label: const Text(
                  'Send Message',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Keep Swiping',
                  style: TextStyle(color: URHeartColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              'UR-Heart',
              style: TextStyle(
                color: URHeartColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.local_fire_department_rounded, color: URHeartColors.brandPrimary, size: 20),
          ],
        ),
        actions: [
          // Streak flame badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: URHeartColors.cardSurface,
              borderRadius: URHeartTheme.radiusPill,
              border: Border.all(color: URHeartColors.accentGold.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.whatshot_rounded, color: URHeartColors.accentGold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_streakCount Days',
                  style: const TextStyle(
                    color: URHeartColors.accentGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // DM token balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: URHeartColors.cardSurface,
              borderRadius: URHeartTheme.radiusPill,
              border: Border.all(color: URHeartColors.brandSecondary.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '$_dmTokens DMs',
                  style: const TextStyle(
                    color: URHeartColors.brandSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Card Stack Viewport
            Expanded(
              child: _buildFeedBody(),
            ),

            // Bottom Action Dock
            if (!_isLoading && _currentIndex < _candidates.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pass Button (X)
                    _buildCircleButton(
                      size: 56,
                      color: URHeartColors.surfaceRaised,
                      icon: Icons.close_rounded,
                      iconColor: URHeartColors.statusDanger,
                      onTap: () => _handleSwipe('pass'),
                    ),

                    // Center Raised Star Button: Direct DM
                    InkWell(
                      onTap: () => widget.onDirectDmTap != null ? widget.onDirectDmTap!() : _handleDirectDmAction(),
                      borderRadius: URHeartTheme.radiusPill,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [URHeartColors.brandSecondary, Color(0xFF0081C9)],
                          ),
                          borderRadius: URHeartTheme.radiusPill,
                          boxShadow: [
                            BoxShadow(
                              color: URHeartColors.brandSecondary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              _t('directDmCta'),
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

                    // Like Button (Heart)
                    _buildCircleButton(
                      size: 56,
                      color: URHeartColors.brandPrimary,
                      icon: Icons.favorite_rounded,
                      iconColor: Colors.white,
                      onTap: () => _handleSwipe('like'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: URHeartColors.brandPrimary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: URHeartColors.statusDanger),
              const SizedBox(height: 12),
              const Text(
                'Could not load feed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFeed,
                style: ElevatedButton.styleFrom(backgroundColor: URHeartColors.brandPrimary),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= _candidates.length) {
      return RadarSonarEmptyState(
        city: _currentUserCity,
        onRefresh: _loadFeed,
      );
    }

    final candidate = _candidates[_currentIndex];
    final primaryPhoto = candidate.primaryPhotoUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Dismissible(
        key: ValueKey('feed_candidate_${candidate.id}_$_currentIndex'),
        direction: DismissDirection.horizontal,
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            // Swiped Right -> Like
            _handleSwipeDismissed('like', candidate);
          } else {
            // Swiped Left -> Pass
            _handleSwipeDismissed('pass', candidate);
          }
        },
        background: Container(
          decoration: BoxDecoration(
            color: URHeartColors.brandPrimary.withValues(alpha: 0.25),
            borderRadius: URHeartTheme.radiusCardLarge,
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 32),
          child: const Icon(Icons.favorite_rounded, color: URHeartColors.brandPrimary, size: 56),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: URHeartColors.statusDanger.withValues(alpha: 0.25),
            borderRadius: URHeartTheme.radiusCardLarge,
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 32),
          child: const Icon(Icons.close_rounded, color: URHeartColors.statusDanger, size: 56),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: URHeartColors.cardSurface,
            borderRadius: URHeartTheme.radiusCardLarge,
            border: Border.all(color: URHeartColors.surfaceRaised),
          ),
          child: ClipRRect(
            borderRadius: URHeartTheme.radiusCardLarge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo background
                if (primaryPhoto.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: primaryPhoto,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: URHeartColors.surfaceRaised,
                      child: const Center(
                        child: CircularProgressIndicator(color: URHeartColors.brandPrimary),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: URHeartColors.surfaceRaised,
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 100, color: URHeartColors.textMuted),
                      ),
                    ),
                  )
                else
                  Container(
                    color: URHeartColors.surfaceRaised,
                    child: const Center(
                      child: Icon(Icons.person_rounded, size: 100, color: URHeartColors.textMuted),
                    ),
                  ),

                // Frosted Privacy Pill (Top Left)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: URHeartTheme.radiusPill,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _t('screenshotBlocked'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Coarse Proximity Pill (Top Right - Zero GPS Leakage)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: URHeartTheme.radiusPill,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: URHeartColors.brandSecondary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${candidate.city} • ${candidate.distanceBadge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Profile Details Overlay (Bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${candidate.fullName}, ${candidate.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (candidate.kycStatus) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, color: URHeartColors.brandSecondary, size: 18),
                            ],
                          ],
                        ),
                        if (candidate.bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            candidate.bio,
                            style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 13),
                          ),
                        ],
                        if (candidate.interests.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: candidate.interests.map((tag) => _buildChip(tag)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: URHeartColors.surfaceRaised,
        borderRadius: URHeartTheme.radiusPill,
      ),
      child: Text(
        label,
        style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
      ),
    );
  }

  Widget _buildCircleButton({
    required double size,
    required Color color,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: size * 0.5),
        ),
      ),
    );
  }
}
