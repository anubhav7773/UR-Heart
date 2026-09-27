import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Floating Action Bar: Pass (✕), Direct Letter (✉ Resonate ✨), and Like (♡)
class FeedActionBar extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onResonate;
  final VoidCallback onLike;
  final bool isDark;

  const FeedActionBar({
    super.key,
    required this.onPass,
    required this.onResonate,
    required this.onLike,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final passBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final passBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final passIconColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final resonateBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final resonateGlow = isDark
        ? DarkSanctuaryTokens.primaryCoralGlow
        : LightSanctuaryTokens.primaryPineGlow;

    final likeBorder = isDark
        ? DarkSanctuaryTokens.primaryCoral.withAlpha(120)
        : LightSanctuaryTokens.terracottaAccent.withAlpha(120);

    final likeIconColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass Button (✕)
          _buildCircularButton(
            size: 54.0,
            bgColor: passBg,
            borderColor: passBorder,
            icon: Icons.close_rounded,
            iconColor: passIconColor,
            iconSize: 26.0,
            onTap: onPass,
          ),
          const SizedBox(width: 14.0),
          // Center Direct Letter Pill (✉ Resonate ✨)
          Expanded(
            child: Container(
              height: 52.0,
              decoration: BoxDecoration(
                color: resonateBg,
                borderRadius: BorderRadius.circular(26.0),
                boxShadow: [
                  BoxShadow(
                    color: resonateGlow,
                    blurRadius: 16.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26.0),
                  onTap: onResonate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'Resonate ✨',
                        style: AppTypography.buttonPrimary.copyWith(
                          color: Colors.white,
                          fontSize: 15.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14.0),
          // Like Button (♡)
          _buildCircularButton(
            size: 54.0,
            bgColor: passBg,
            borderColor: likeBorder,
            icon: Icons.favorite_rounded,
            iconColor: likeIconColor,
            iconSize: 26.0,
            onTap: onLike,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required double size,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}
