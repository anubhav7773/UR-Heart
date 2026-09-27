import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Metrics display pill showing dialogue status count in Screen 8
class ChatsMetricPill extends StatelessWidget {
  final int totalActive;
  final int directCount;
  final int mutualCount;
  final bool isDark;

  const ChatsMetricPill({
    super.key,
    required this.totalActive,
    required this.directCount,
    required this.mutualCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.chipBackground;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final primaryTextColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;
    final secondaryTextColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: isDark ? DarkSanctuaryTokens.badgeOnline : LightSanctuaryTokens.badgeOnline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            '$totalActive ACTIVE DIALOGUES',
            style: AppTypography.caption.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            ' · $directCount Direct · $mutualCount Mutual',
            style: AppTypography.caption.copyWith(
              color: secondaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
