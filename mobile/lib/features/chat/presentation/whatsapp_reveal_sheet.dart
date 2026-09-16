import 'package:flutter/material.dart';
import 'package:ur_heart/core/config/theme.dart';
import 'package:ur_heart/core/utils/vernacular_strings.dart';

/// Screen 5: Mutual WhatsApp Reveal 3-Ad Checkpoint Bottom Sheet
/// Spec: URH-UIX-009 Section 3 Screen 5
class WhatsAppRevealSheet extends StatelessWidget {
  final String lang;
  final int userAdsWatched; // e.g. 2
  final int matchAdsWatched; // e.g. 1
  final VoidCallback? onWatchAdTap;

  const WhatsAppRevealSheet({
    super.key,
    this.lang = 'en',
    this.userAdsWatched = 2,
    this.matchAdsWatched = 1,
    this.onWatchAdTap,
  });

  String _t(String key, [Map<String, String>? args]) =>
      VernacularStrings.tr(key, lang: lang, args: args);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: URHeartColors.cardSurface,
        borderRadius: URHeartTheme.radiusModal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: URHeartColors.textMuted.withOpacity(0.5),
                borderRadius: URHeartTheme.radiusPill,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title Area
          Text(
            _t('waRevealTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: URHeartColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('waRevealProgress'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Dual-Sided Progress Tracker Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: URHeartColors.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Column 1: Your Progress
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'You / आप',
                        style: TextStyle(
                          color: URHeartColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isDone = index < userAdsWatched;
                          final isCurrent = index == userAdsWatched;
                          return _buildBadge(
                            isDone: isDone,
                            isCurrent: isCurrent,
                            label: isDone ? '✓' : (isCurrent ? '▶' : '⏳'),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$userAdsWatched of 3 Watched',
                        style: const TextStyle(color: URHeartColors.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 64,
                  color: URHeartColors.cardSurface,
                ),

                // Column 2: Match Progress
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Rahul',
                        style: TextStyle(
                          color: URHeartColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isDone = index < matchAdsWatched;
                          return _buildBadge(
                            isDone: isDone,
                            isCurrent: false,
                            label: isDone ? '✓' : '⏳',
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$matchAdsWatched of 3 Watched',
                        style: const TextStyle(color: URHeartColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            height: 52,
            child: InkWell(
              onTap: onWatchAdTap,
              borderRadius: URHeartTheme.radiusPill,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [URHeartColors.statusSuccess, Color(0xFF00B4D8)],
                  ),
                  borderRadius: URHeartTheme.radiusPill,
                  boxShadow: [
                    BoxShadow(
                      color: URHeartColors.statusSuccess.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Watch Video Ad (30s) to Progress [$userAdsWatched/3]',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Disclaimer Footer
          Text(
            _t('waRevealDisclaimer'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: URHeartColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required bool isDone,
    required bool isCurrent,
    required String label,
  }) {
    Color bg = isDone ? URHeartColors.statusSuccess : (isCurrent ? URHeartColors.accentGold.withOpacity(0.2) : Colors.transparent);
    Color border = isDone ? URHeartColors.statusSuccess : (isCurrent ? URHeartColors.accentGold : URHeartColors.textMuted);
    Color textColor = isDone ? Colors.black87 : (isCurrent ? URHeartColors.accentGold : URHeartColors.textMuted);

    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
