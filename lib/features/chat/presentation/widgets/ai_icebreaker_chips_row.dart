import 'package:flutter/material.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// 3 Bespoke AI contextual starter chips for empty/fresh dialogues
class AiIcebreakerChipsRow extends StatelessWidget {
  final bool isDark;
  final List<String> icebreakers;
  final void Function(String prompt) onSelectIcebreaker;

  const AiIcebreakerChipsRow({
    super.key,
    required this.isDark,
    required this.icebreakers,
    required this.onSelectIcebreaker,
  });

  @override
  Widget build(BuildContext context) {
    if (icebreakers.isEmpty) return const SizedBox.shrink();

    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: gold, size: 13.0),
                const SizedBox(width: 5.0),
                Text(
                  'MINDFUL OPENINGS (AI BESPOKE)',
                  style: TextStyle(
                    color: gold,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          SizedBox(
            height: 38.0,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: icebreakers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8.0),
              itemBuilder: (context, index) {
                final prompt = icebreakers[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(19.0),
                  onTap: () => onSelectIcebreaker(prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(19.0),
                      border: Border.all(color: gold.withValues(alpha: 0.4), width: 0.9),
                    ),
                    child: Center(
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: primaryText,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
