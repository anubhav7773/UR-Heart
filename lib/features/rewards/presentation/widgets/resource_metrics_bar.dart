import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Resource Status Metrics Bar displaying swipes, direct letters, social reveal tokens & status badge (< 130 lines)
class ResourceMetricsBar extends StatelessWidget {
  final bool isDark;
  final int swipesRemaining;
  final int directLetters;
  final int revealTokens;
  final bool isAdFree;

  const ResourceMetricsBar({
    super.key,
    required this.isDark,
    required this.swipesRemaining,
    required this.directLetters,
    this.revealTokens = 0,
    required this.isAdFree,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headline = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final muted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final coral = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Row(
        children: [
          // 1. Swipes / Profile Skips metric
          Expanded(
            child: _buildPill(
              icon: Icons.auto_awesome,
              iconColor: pine,
              label: 'Profile Skips',
              countText: isAdFree ? '∞' : '$swipesRemaining',
              headlineColor: headline,
              mutedColor: muted,
            ),
          ),
          Container(width: 1.0, height: 26.0, color: cardBorder, margin: const EdgeInsets.symmetric(horizontal: 6.0)),

          // 2. Direct letters / msgs metric
          Expanded(
            child: _buildPill(
              icon: Icons.mail_outline,
              iconColor: gold,
              label: 'Direct Msgs',
              countText: '$directLetters',
              headlineColor: headline,
              mutedColor: muted,
            ),
          ),
          Container(width: 1.0, height: 26.0, color: cardBorder, margin: const EdgeInsets.symmetric(horizontal: 6.0)),

          // 3. Social Handle Reveal Token metric
          Expanded(
            child: _buildPill(
              icon: Icons.key_rounded,
              iconColor: coral,
              label: 'Social Reveals',
              countText: isAdFree ? '∞' : '$revealTokens',
              headlineColor: headline,
              mutedColor: muted,
            ),
          ),
          Container(width: 1.0, height: 26.0, color: cardBorder, margin: const EdgeInsets.symmetric(horizontal: 6.0)),

          // 4. Sovereign status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: (isAdFree ? gold : pine).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: (isAdFree ? gold : pine).withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isAdFree ? Icons.verified : Icons.spa_outlined, size: 11.0, color: isAdFree ? gold : pine),
                const SizedBox(width: 3.0),
                Text(
                  isAdFree ? 'Sovereign' : 'Mindful',
                  style: TextStyle(
                    color: isAdFree ? gold : pine,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String countText,
    required Color headlineColor,
    required Color mutedColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.0, color: iconColor),
            const SizedBox(width: 3.0),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  countText,
                  style: AppTypography.titleH2.copyWith(
                    color: headlineColor,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: mutedColor, fontSize: 9.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
