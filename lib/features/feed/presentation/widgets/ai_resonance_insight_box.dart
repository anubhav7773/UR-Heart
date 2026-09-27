import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class AiResonanceInsightBox extends StatelessWidget {
  final bool isDark;
  final String insightText;
  final int resonanceScore;

  const AiResonanceInsightBox({
    super.key,
    required this.isDark,
    required this.insightText,
    required this.resonanceScore,
  });

  @override
  Widget build(BuildContext context) {
    final gold = isDark
        ? DarkSanctuaryTokens.goldAccent
        : LightSanctuaryTokens.goldAccent;
    final surfaceMuted = isDark
        ? DarkSanctuaryTokens.surfaceMuted
        : LightSanctuaryTokens.surfaceMuted;
    final primaryText = isDark
        ? DarkSanctuaryTokens.primaryText
        : LightSanctuaryTokens.primaryText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceMuted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'RESONANCE ALIGNMENT',
                    style: TextStyle(
                      color: gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$resonanceScore% MATCH',
                  style: TextStyle(
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insightText,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: primaryText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
