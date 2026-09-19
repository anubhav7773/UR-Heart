import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import '../../data/feed_candidate_model.dart';

class FeedCard extends StatefulWidget {
  final FeedCandidateModel candidate;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onDirectDm;

  const FeedCard({
    super.key,
    required this.candidate,
    required this.onLike,
    required this.onPass,
    required this.onDirectDm,
  });

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  int _currentPhotoIndex = 0;

  void _nextPhoto() {
    if (_currentPhotoIndex < widget.candidate.photos.length - 1) {
      HapticFeedback.selectionClick();
      setState(() => _currentPhotoIndex++);
    }
  }

  void _previousPhoto() {
    if (_currentPhotoIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() => _currentPhotoIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final photos = candidate.photos;
    final currentPhoto = photos.isNotEmpty && _currentPhotoIndex < photos.length
        ? photos[_currentPhotoIndex]
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Layer: Background Photo with BlurHash & Cache
            if (currentPhoto != null && currentPhoto.photoUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: currentPhoto.photoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => BlurHash(
                  hash: currentPhoto.blurHash,
                  imageFit: BoxFit.cover,
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF1B1B24),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white24, size: 80),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xFF1B1B24),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white24, size: 80),
                ),
              ),

            // 2. Layer: Left/Right Tap Area for Photo Swapping
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _previousPhoto,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _nextPhoto,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

            // 3. Layer: Story Progress Bar (Top Photo Slot Indicators)
            if (photos.length > 1)
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(photos.length, (index) {
                    final bool isCurrent = index == _currentPhotoIndex;
                    return Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFFFF2E63)
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // 4. Layer: Dark Romantic Vignette Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.98),
                    ],
                    stops: const [0.4, 0.6, 0.85, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 5. Layer: User Details & Action Controls
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Name & Verified Badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          candidate.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Color(0xFF06D6A0), size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Distance & Location Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFFFD166), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              candidate.distanceKm != null
                                  ? "Nearby ${candidate.distanceKm} km"
                                  : (candidate.detectedLocality ?? candidate.city),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      if (candidate.streakCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2E63).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "🔥 ${candidate.streakCount} Day Streak",
                            style: const TextStyle(color: Color(0xFFFF2E63), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),

                  if (candidate.bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      candidate.bio,
                      style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Bottom Action Buttons (Pass, Direct DM, Like)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pass Button
                      _buildRoundActionBtn(
                        icon: Icons.close_rounded,
                        color: const Color(0xFFFF334B),
                        size: 54,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onPass();
                        },
                      ),

                      // Direct DM Star Action
                      _buildRoundActionBtn(
                        icon: Icons.flash_on_rounded,
                        color: const Color(0xFFFFD166),
                        size: 46,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onDirectDm();
                        },
                      ),

                      // Like Button
                      _buildRoundActionBtn(
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFF06D6A0),
                        size: 54,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onLike();
                        },
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

  Widget _buildRoundActionBtn({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF16161D).withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: color, size: size * 0.46),
        ),
      ),
    );
  }
}
