import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';

/// Expandable legal disclosure card for Screen 1 Mindful Consent
class ConsentAccordionCard extends ConsumerStatefulWidget {
  final String category;
  final String title;
  final String purposeSummary;
  final String detailedText;

  const ConsentAccordionCard({
    super.key,
    required this.category,
    required this.title,
    required this.purposeSummary,
    required this.detailedText,
  });

  @override
  ConsumerState<ConsentAccordionCard> createState() =>
      _ConsentAccordionCardState();
}

class _ConsentAccordionCardState extends ConsumerState<ConsentAccordionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final categoryColor = isDark
        ? DarkSanctuaryTokens.accentGold
        : LightSanctuaryTokens.terracottaAccent;

    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final bodyColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.toUpperCase(),
                          style: AppTypography.accordionCategory.copyWith(
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          widget.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: mutedColor,
                    size: 20.0,
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                widget.purposeSummary,
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12.0),
                Divider(color: cardBorder, height: 1.0),
                const SizedBox(height: 12.0),
                Text(
                  widget.detailedText,
                  style: AppTypography.bodySmall.copyWith(
                    color: bodyColor,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
