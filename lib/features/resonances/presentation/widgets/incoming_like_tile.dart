import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/resonances_repository.dart';

/// Card tile for an incoming like in Screen 7 with BlurHash and '💬 Chat' CTA
class IncomingLikeTile extends StatelessWidget {
  final IncomingLike like;
  final bool isDark;
  final bool isProcessing;
  final VoidCallback onChatTap;

  const IncomingLikeTile({
    super.key,
    required this.like,
    required this.isDark,
    this.isProcessing = false,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final goldColor = isDark
        ? DarkSanctuaryTokens.accentGold
        : LightSanctuaryTokens.terracottaAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Avatar with fallback initials
          CircleAvatar(
            radius: 28.0,
            backgroundColor: isDark ? const Color(0xFF131F19) : const Color(0xFFF2EFE9),
            child: Text(
              like.fullName.isNotEmpty ? like.fullName[0] : '?',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 20.0),
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${like.fullName}, ${like.age}',
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    const SizedBox(width: 6.0),
                    Icon(Icons.favorite, size: 14.0, color: goldColor),
                  ],
                ),
                const SizedBox(height: 2.0),
                Text(
                  'Liked you ${like.relativeTime} · ${like.matchScore}% resonance',
                  style: AppTypography.caption.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 4.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: isDark ? DarkSanctuaryTokens.secondaryPine : LightSanctuaryTokens.chipBackground,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    like.sharedInterest,
                    style: TextStyle(fontSize: 11.0, color: titleColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          // '💬 Chat' CTA Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
            ),
            onPressed: isProcessing ? null : onChatTap,
            child: isProcessing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💬', style: TextStyle(fontSize: 12.0)),
                      SizedBox(width: 4.0),
                      Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
