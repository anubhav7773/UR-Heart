import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../navigation/presentation/screens/sanctuary_navigation_shell.dart';

class OutOfSwipesModal extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onWatchAdTriggered;

  const OutOfSwipesModal({
    super.key,
    required this.isDark,
    required this.onWatchAdTriggered,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.surface;
    final primaryText = isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;
    final subText = isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final terracotta = isDark
        ? DarkSanctuaryTokens.accentTerracotta
        : LightSanctuaryTokens.accentTerracotta;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: subText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Icon(Icons.hourglass_empty_rounded, size: 36, color: terracotta),
          const SizedBox(height: 12),
          Text(
            'Daily Presence Quota Exhausted',
            style: TextStyle(
              fontFamily: 'Serif',
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily Mindful Quota Exhausted',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subText.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sanctuary honors intentional connections over infinite scrolling. '
            'Take a gentle 10s reflection to replenish your presence, or acquire sovereign freedom.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: subText, height: 1.4),
          ),
          const SizedBox(height: 20),
          // Path A: 10s Rewarded Video Sponsor
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: pine,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_circle_outline, color: Colors.white, size: 18),
              label: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Watch 10s Reflection (+10 Swipes Free)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Watch Reflection (10s) · +10 Skips',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onWatchAdTriggered();
              },
            ),
          ),
          const SizedBox(height: 10),
          // Path B: Sovereign Pass / Store Uplink
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: terracotta, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(Icons.workspace_premium_outlined, color: terracotta, size: 18),
              label: Text(
                'Get Sovereign Pass (Unlimited Swipes ➔)',
                style: TextStyle(color: terracotta, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(navigationIndexProvider.notifier).state = 3;
              },
            ),
          ),
        ],
      ),
    );
  }
}
