import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

/// Editorial serif quote container displaying authentic intention & values
class MindfulIntentCard extends StatelessWidget {
  final String? intentQuote;
  final String? bio;
  final List<String>? interestTags;
  final bool isDark;

  const MindfulIntentCard({
    super.key,
    this.intentQuote,
    this.bio,
    this.interestTags,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceMuted = isDark
        ? DarkSanctuaryTokens.surfaceMuted
        : LightSanctuaryTokens.surfaceMuted;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final primaryText = isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;
    final accent = isDark
        ? DarkSanctuaryTokens.accentTerracotta
        : LightSanctuaryTokens.accentTerracotta;
    final secondaryText = isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;

    final displayText = bio ?? intentQuote ?? '';
    final tags = interestTags ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: surfaceMuted,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote, size: 18.0, color: accent),
              const SizedBox(width: 6.0),
              Text(
                'AUTHENTIC INTENTION',
                style: TextStyle(
                  color: accent,
                  letterSpacing: 1.1,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (displayText.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text(
              '"$displayText"',
              style: TextStyle(
                fontFamily: 'Serif',
                fontStyle: FontStyle.italic,
                color: primaryText,
                fontSize: 14.0,
                height: 1.45,
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: cardBorder, width: 0.8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(fontSize: 11.5, color: secondaryText, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
