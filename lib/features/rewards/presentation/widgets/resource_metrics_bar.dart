import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Resource Status Metrics Bar displaying swipes, direct letters & ad-free badge (< 130 lines)
class ResourceMetricsBar extends StatelessWidget {
  final bool isDark;
  final int swipesRemaining;
  final int directLetters;
  final bool isAdFree;

  const ResourceMetricsBar({
    super.key,
    required this.isDark,
    required this.swipesRemaining,
    required this.directLetters,
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Swipes metric
          _buildPill(
            icon: Icons.auto_awesome,
            iconColor: pine,
            label: 'Swipes Remaining',
            countText: isAdFree ? '∞' : '$swipesRemaining',
            headlineColor: headline,
            mutedColor: muted,
          ),
          Container(width: 1.0, height: 28.0, color: cardBorder),
          // Direct letters metric
          _buildPill(
            icon: Icons.mail_outline,
            iconColor: gold,
            label: 'Direct Letters',
            countText: '$directLetters',
            headlineColor: headline,
            mutedColor: muted,
          ),
          Container(width: 1.0, height: 28.0, color: cardBorder),
          // Sovereign status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: (isAdFree ? gold : pine).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: (isAdFree ? gold : pine).withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isAdFree ? Icons.verified : Icons.spa_outlined, size: 12.0, color: isAdFree ? gold : pine),
                const SizedBox(width: 4.0),
                Text(
                  isAdFree ? 'Sovereign' : 'Mindful',
                  style: TextStyle(
                    color: isAdFree ? gold : pine,
                    fontSize: 11.0,
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
          children: [
            Icon(icon, size: 13.0, color: iconColor),
            const SizedBox(width: 4.0),
            Text(countText, style: AppTypography.titleH2.copyWith(color: headlineColor, fontSize: 15.0)),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(label, style: TextStyle(color: mutedColor, fontSize: 10.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
