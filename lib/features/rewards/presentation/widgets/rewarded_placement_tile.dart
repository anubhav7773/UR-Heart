import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Interactive rewarded ad placement card for user-initiated sponsorship (< 160 lines)
class RewardedPlacementTile extends StatelessWidget {
  final String title;
  final String durationTag;
  final String rewardDescription;
  final String buttonText;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const RewardedPlacementTile({
    super.key,
    required this.title,
    this.durationTag = '',
    required this.rewardDescription,
    this.buttonText = 'Watch',
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.sanctuaryPine;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final buttonBg = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.chipBackground;
    final buttonTextColor = isDark ? Colors.white : LightSanctuaryTokens.sanctuaryPine;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.buttonPrimary.copyWith(
                          color: headlineColor,
                          fontSize: 14.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (durationTag.isNotEmpty) ...[
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          durationTag,
                          style: TextStyle(color: accentColor, fontSize: 10.0, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  rewardDescription,
                  style: TextStyle(color: mutedColor, fontSize: 12.0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonTextColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            onPressed: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: TextStyle(color: buttonTextColor, fontWeight: FontWeight.w700, fontSize: 12.0),
                ),
                const SizedBox(width: 4.0),
                Icon(Icons.arrow_forward_ios, size: 10.0, color: buttonTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
