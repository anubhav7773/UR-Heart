import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Editorial banner conveying UR-Heart's zero-paywall philosophy
class ZeroPaywallBanner extends StatelessWidget {
  final bool isDark;

  const ZeroPaywallBanner({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final bodyColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa_outlined, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SACRED BALANCE · FREE OR SOVEREIGN',
                  style: AppTypography.accordionCategory.copyWith(
                    color: accentColor,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Earn Free Access or Ascend Sovereign',
            style: AppTypography.titleH2.copyWith(
              color: headlineColor,
              fontSize: 20.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy full sanctuary privileges for free through mindful sponsor reflections, or unlock Sovereign Passes for complete ad-free silence, infinite discoveries, and instant reveals.',
            style: AppTypography.bodyStandard.copyWith(
              color: bodyColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
