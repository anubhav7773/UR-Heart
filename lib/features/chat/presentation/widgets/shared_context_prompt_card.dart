import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Top-anchored shared connection context card for 1:1 dialogue
class SharedContextPromptCard extends StatelessWidget {
  final bool isDark;
  final String promptText;

  const SharedContextPromptCard({
    super.key,
    required this.isDark,
    required this.promptText,
  });

  @override
  Widget build(BuildContext context) {
    if (promptText.trim().isEmpty) return const SizedBox.shrink();

    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surfaceCard = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 12.0, color: gold),
              const SizedBox(width: 6.0),
              Text(
                'SHARED RESONANCE CONTEXT',
                style: TextStyle(
                  color: gold,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5.0),
          Text(
            '"$promptText"',
            style: TextStyle(
              color: primaryText,
              fontSize: 13.0,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
