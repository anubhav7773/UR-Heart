import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/feed_repository.dart';
import 'candidate_photo_carousel.dart';
import 'mindful_intent_card.dart';

/// Gesture-driven swipeable card stack with dynamic angle curves (-15 to +15 deg)
class SanctuaryCardDeck extends StatefulWidget {
  final CandidateProfile profile;
  final bool isDark;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeUp;

  const SanctuaryCardDeck({
    super.key,
    required this.profile,
    required this.isDark,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
  });

  @override
  State<SanctuaryCardDeck> createState() => _SanctuaryCardDeckState();
}

class _SanctuaryCardDeckState extends State<SanctuaryCardDeck> {
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = widget.isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final titleColor = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = widget.isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final verifiedTeal = widget.isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    final goldColor = widget.isDark
        ? DarkSanctuaryTokens.accentGold
        : LightSanctuaryTokens.terracottaAccent;

    final chipBg = widget.isDark
        ? DarkSanctuaryTokens.secondaryPine
        : LightSanctuaryTokens.chipBackground;

    // Rotation curve: Max 15 degrees (~0.26 radians) based on horizontal offset
    final rotationAngle = (_dragOffset.dx / 300.0).clamp(-0.26, 0.26);

    return Listener(
      onPointerMove: (event) {
        setState(() {
          _dragOffset += event.delta;
        });
      },
      onPointerUp: (event) {
        if (_dragOffset.dx > 100) {
          widget.onSwipeRight();
        } else if (_dragOffset.dx < -100) {
          widget.onSwipeLeft();
        } else if (_dragOffset.dy < -100) {
          widget.onSwipeUp();
        }
        setState(() {
          _dragOffset = Offset.zero;
        });
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotationAngle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: cardBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(widget.isDark ? 50 : 20),
                  blurRadius: 18.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23.0),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Carousel (Height 340)
                    SizedBox(
                      height: 340.0,
                      width: double.infinity,
                      child: CandidatePhotoCarousel(
                        photoUrls: widget.profile.photoUrls,
                        blurHashes: widget.profile.blurHashes,
                        isDark: widget.isDark,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Resonance Score & Verified Badges Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: goldColor.withAlpha(35),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: goldColor, width: 1.0),
                                ),
                                child: Text(
                                  '${widget.profile.resonanceScore}% RESONANCE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: goldColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (widget.profile.isVerified)
                                Icon(Icons.verified, size: 18.0, color: verifiedTeal),
                              const SizedBox(width: 8.0),
                              if (widget.profile.isOnline)
                                Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    color: verifiedTeal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          // Name & Age
                          Text(
                            '${widget.profile.fullName}, ${widget.profile.age}',
                            style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 24.0),
                          ),
                          const SizedBox(height: 4.0),
                          // Location & Distance
                          Row(
                            children: [
                              Icon(Icons.near_me_outlined, size: 14.0, color: mutedColor),
                              const SizedBox(width: 4.0),
                              Text(
                                '${widget.profile.locationName} · ${widget.profile.distanceKm} km away',
                                style: AppTypography.caption.copyWith(color: mutedColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14.0),
                          // Mindful Intent Editorial Quote
                          MindfulIntentCard(
                            intentQuote: widget.profile.intentQuote,
                            isDark: widget.isDark,
                          ),
                          const SizedBox(height: 14.0),
                          // Interests Wrap Chips
                          Wrap(
                            spacing: 6.0,
                            runSpacing: 6.0,
                            children: widget.profile.interests.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(fontSize: 12.0, color: titleColor, fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
