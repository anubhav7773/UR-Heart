import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'sanctuary_feedback_sheet.dart';

class CommunityFeedbackCard extends StatelessWidget {
  final bool isDark;

  const CommunityFeedbackCard({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => const SanctuaryFeedbackSheet(),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.rate_review_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Feedback & Bug Report',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: headlineColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Direct',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Report bugs, suggest features, or share thoughts with developers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: mutedColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
