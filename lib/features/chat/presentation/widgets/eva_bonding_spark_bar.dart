import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Production-Grade Non-Intrusive In-Chat Eva Bonding Wingmate Bar
/// Analyzes ongoing conversation and provides high-EQ bonding sparks
/// directly above the text input bar without degrading chat UX.
class EvaBondingSparkBar extends StatelessWidget {
  final bool isDark;
  final List<String> sparks;
  final ValueChanged<String> onSelectSpark;
  final VoidCallback onDismiss;

  const EvaBondingSparkBar({
    super.key,
    required this.isDark,
    required this.sparks,
    required this.onSelectSpark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (sparks.isEmpty) return const SizedBox.shrink();

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard.withValues(alpha: 0.95)
        : LightSanctuaryTokens.surfaceCard.withValues(alpha: 0.95);
    final border = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final gold = isDark
        ? DarkSanctuaryTokens.goldAccent
        : LightSanctuaryTokens.goldAccent;
    final textHeadline = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final textMuted = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final chipBg = isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.chipBackground;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(color: border, width: 0.8),
          bottom: BorderSide(color: border.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: gold, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'EVA BONDING WINGMATE',
                      style: TextStyle(
                        color: gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.close_rounded, size: 14, color: textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: sparks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final spark = sparks[index];
                return InkWell(
                  onTap: () => onSelectSpark(spark),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: gold.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          spark,
                          style: TextStyle(
                            color: textHeadline,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_upward_rounded, size: 11, color: gold),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
