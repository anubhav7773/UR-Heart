import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import 'photo_carousel_with_dots.dart';
import 'ai_resonance_insight_box.dart';
import 'mindful_intent_card.dart';

class CandidateProfileCard extends StatefulWidget {
  final Map<String, dynamic> candidate;
  final bool isDark;
  final void Function(String swipeType) onSwipeCompleted;

  const CandidateProfileCard({
    super.key,
    required this.candidate,
    required this.isDark,
    required this.onSwipeCompleted,
  });

  @override
  State<CandidateProfileCard> createState() => _CandidateProfileCardState();
}

class _CandidateProfileCardState extends State<CandidateProfileCard> {
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final surfaceColor = widget.isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.surface;
    final primaryTextColor = widget.isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;
    final secondaryTextColor = widget.isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;
    final pine = widget.isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final terracotta = widget.isDark
        ? DarkSanctuaryTokens.accentTerracotta
        : LightSanctuaryTokens.accentTerracotta;

    final rawPhotos = (widget.candidate['photos'] as List<dynamic>?)?.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() ??
        (widget.candidate['photo_urls'] as List<dynamic>?)?.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() ??
        [];
    final avatar = (widget.candidate['avatar_url'] as String? ?? widget.candidate['avatar'] as String?)?.trim();
    final photos = <String>[];
    if (avatar != null && avatar.isNotEmpty) {
      photos.add(avatar);
    }
    for (final p in rawPhotos) {
      if (!photos.contains(p)) {
        photos.add(p);
      }
    }
    final blurHashes = (widget.candidate['blur_hashes'] as List<dynamic>?)?.cast<String>() ?? [];

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) {
        setState(() {
          _dragOffset += event.delta;
          // Normalized rotation between -15 and +15 degrees
          _dragAngle = (_dragOffset.dx / screenSize.width) * (math.pi / 12);
        });
      },
      onPointerUp: (event) {
        if (_dragOffset.dx > 100) {
          _completeSwipe('like');
        } else if (_dragOffset.dx < -100) {
          _completeSwipe('pass');
        } else {
          setState(() {
            _dragOffset = Offset.zero;
            _dragAngle = 0.0;
          });
        }
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _dragAngle,
          alignment: Alignment.bottomCenter,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PhotoCarouselWithDots(
                          photos: photos,
                          blurHashes: blurHashes,
                          isDark: widget.isDark,
                          isKycVerified: widget.candidate['kyc_status'] as bool? ??
                              widget.candidate['is_verified'] as bool? ??
                              false,
                          locationTag: widget.candidate['location_name'] as String? ?? 'Saket, Ayodhya',
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${widget.candidate['full_name'] ?? 'Sanctuary Member'}, ${widget.candidate['age'] ?? 22}',
                                    style: TextStyle(
                                      fontFamily: 'Serif',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  if (widget.candidate['kyc_status'] == true ||
                                      widget.candidate['is_verified'] == true) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.verified, size: 20, color: pine),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.candidate['gender'] ?? 'Presence'} · ${widget.candidate['profession'] ?? widget.candidate['looking_for'] ?? 'Mindful Creator'}',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AiResonanceInsightBox(
                                isDark: widget.isDark,
                                insightText: widget.candidate['ai_insight'] as String? ??
                                    widget.candidate['ai_resonance_insight'] as String? ??
                                    'A shared reverence for quiet reflection and intentional connection connects your paths.',
                                resonanceScore: (widget.candidate['resonance_score'] as num?)?.toInt() ?? 90,
                              ),
                              const SizedBox(height: 16),
                              MindfulIntentCard(
                                isDark: widget.isDark,
                                bio: widget.candidate['authentic_intention'] as String? ??
                                    widget.candidate['bio'] as String? ??
                                    widget.candidate['intent_quote'] as String? ??
                                    '',
                                interestTags: (widget.candidate['interests'] as List<dynamic>?)?.cast<String>() ??
                                    (widget.candidate['tags'] as List<dynamic>?)?.cast<String>() ??
                                    [],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Swipe Right (Like) Pine Tint Overlay
              if (_dragOffset.dx > 20)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: pine.withValues(alpha: math.min(0.25, _dragOffset.dx / 400)),
                      ),
                    ),
                  ),
                ),
              // Swipe Left (Pass) Terracotta Tint Overlay
              if (_dragOffset.dx < -20)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: terracotta.withValues(alpha: math.min(0.25, -_dragOffset.dx / 400)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _completeSwipe(String type) {
    widget.onSwipeCompleted(type);
    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
    });
  }
}
