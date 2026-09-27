import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/sanctuary_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import 'consent_accordion_card.dart';

class ConsentAccordionGroup extends ConsumerWidget {
  const ConsentAccordionGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.gavel_rounded,
              size: 16,
              color: isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine,
            ),
            const SizedBox(width: 8),
            Text(
              'Statutory Declarations',
              style: SanctuaryTypography.accordionCategory.copyWith(color: primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const ConsentAccordionCard(
          category: 'Digital Personal Data',
          title: 'DPDP Act 2023 & Data Governance',
          purposeSummary: 'Point-of-collection transparency and non-negotiable user privacy.',
          detailedText:
              'Under Sections 5 and 6 of India’s DPDP Act 2023, your personal data is processed solely for identity verification and mutual matching. Data is encrypted at rest using AES-256 and never sold to third parties.',
        ),
        const ConsentAccordionCard(
          category: 'Intermediary Guidelines',
          title: 'Rule 3(2) IT Rules & Grievance Redressal',
          purposeSummary: 'Statutory 24h complaint acknowledgment and 15-day resolution.',
          detailedText:
              'In compliance with Information Technology Rules 2021, UR-Heart maintains an appointed Grievance Officer reachable at grievance@urheart.app. All safety violations are ticketed within 24 hours.',
        ),
        const ConsentAccordionCard(
          category: 'Community Safe Space',
          title: 'Zero Harassment & Community EULA',
          purposeSummary: 'Uncompromising conduct standard: Zero tolerance for abuse.',
          detailedText:
              'UR-Heart strictly forbids unsolicited contact sharing, hate speech, explicit content, or harassment. Accounts violating community trust are immediately quarantined.',
        ),
      ],
    );
  }
}
