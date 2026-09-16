import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';
import 'package:ur_heart/core/security/secure_screen_mixin.dart';

/// Screen 3: Discovery Swipe Feed with Rewarded DM & Ad Countdown HUD
/// Spec: URH-UIX-009 Section 3 Screen 3
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

  int _swipesUntilAd = 4;

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: widget.lang, args: args);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: URHeartColors.canvasBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'UR-Heart',
              style: TextStyle(
                color: URHeartColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.local_fire_department_rounded, color: URHeartColors.brandPrimary, size: 20),
          ],
        ),
        actions: [
          // Streak flame badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: URHeartColors.cardSurface,
              borderRadius: URHeartTheme.radiusPill,
              border: Border.all(color: URHeartColors.accentGold.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.whatshot_rounded, color: URHeartColors.accentGold, size: 16),
                SizedBox(width: 4),
                Text(
                  '7 Days',
                  style: TextStyle(
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
              border: Border.all(color: URHeartColors.brandSecondary.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🪙', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text(
                  '12 DMs',
                  style: TextStyle(
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
            // Paced Ad Countdown Pill directly below top bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: URHeartColors.cardSurface,
                  borderRadius: URHeartTheme.radiusPill,
                  border: Border.all(color: URHeartColors.brandSecondary.withOpacity(0.6)),
                ),
                child: Text(
                  _t('feedAdCounter', {'x': '$_swipesUntilAd'}),
                  style: const TextStyle(
                    color: URHeartColors.brandSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Card Stack Viewport
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: URHeartColors.cardSurface,
                    borderRadius: URHeartTheme.radiusCardLarge,
                    border: Border.all(color: URHeartColors.surfaceRaised),
                  ),
                  child: ClipRRect(
                    borderRadius: URHeartTheme.radiusCardLarge,
                    child: Stack(
                      children: [
                        // Placeholder visual background
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
                              color: Colors.black.withOpacity(0.6),
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

                        // City Pill (Top Right)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: URHeartTheme.radiusPill,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, color: URHeartColors.brandSecondary, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Lucknow (4 km)',
                                  style: TextStyle(
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
                                  Colors.black.withOpacity(0.85),
                                  Colors.black,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Priya, 23',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.verified_rounded, color: URHeartColors.brandSecondary, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Lover of chai, old Hindi songs, and digital painting.',
                                  style: TextStyle(color: URHeartColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildChip('☕ Chai'),
                                    _buildChip('🎨 Painting'),
                                    _buildChip('🎵 Bollywood'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Dock (3 circular buttons >= 48dp)
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
                    onTap: widget.onPassTap,
                  ),

                  // Center Raised Star Button: Watch 10s Ad -> 3 Direct DMs
                  InkWell(
                    onTap: widget.onDirectDmTap,
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
                            color: URHeartColors.brandSecondary.withOpacity(0.3),
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
                    onTap: widget.onLikeTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
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
