import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Top anchored box showing shared prompt annotation and context quote
class SharedContextHeader extends StatelessWidget {
  final String sharedQuote;
  final bool isDark;

  const SharedContextHeader({
    super.key,
    required this.sharedQuote,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (sharedQuote.trim().isEmpty) return const SizedBox.shrink();

    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.chipBackground;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final bodyColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 20.0, color: accentColor),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARED RESONANCE CONTEXT',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  '"$sharedQuote"',
                  style: AppTypography.caption.copyWith(
                    color: bodyColor,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 10.0, color: mutedColor),
                    const SizedBox(width: 4.0),
                    Text(
                      'End-to-end encrypted · Zero logs',
                      style: TextStyle(color: mutedColor, fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
