import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/sanctuary_typography.dart';

class PassageGuideBox extends ConsumerWidget {
  final String email;

  const PassageGuideBox({super.key, this.email = 'your email'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final cardBg = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final secondary = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.accentTerracotta;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3-STEP MINDFUL PASSAGE',
            style: SanctuaryTypography.accordionCategory.copyWith(color: gold),
          ),
          const SizedBox(height: 16),
          _buildStep(
            number: '1',
            title: 'Open your inbox',
            description: 'Find the heartfelt verification email sent to $email.',
            primary: primary,
            secondary: secondary,
            gold: gold,
          ),
          const SizedBox(height: 12),
          _buildStep(
            number: '2',
            title: 'Tap verification link',
            description: 'Authenticate your device to unlock intentional matching.',
            primary: primary,
            secondary: secondary,
            gold: gold,
          ),
          const SizedBox(height: 12),
          _buildStep(
            number: '3',
            title: 'Return to your sanctuary',
            description: 'Begin building your authentic, verified persona.',
            primary: primary,
            secondary: secondary,
            gold: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required Color primary,
    required Color secondary,
    required Color gold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: gold.withValues(alpha: 0.15),
          child: Text(
            number,
            style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(color: secondary, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
