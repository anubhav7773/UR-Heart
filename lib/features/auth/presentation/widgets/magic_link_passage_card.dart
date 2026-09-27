import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';

/// 3-Step Mindful Passage Guide and 45s Cooldown Timer card for Screen 3
class MagicLinkPassageCard extends ConsumerWidget {
  const MagicLinkPassageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final accentColor = isDark
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

    final cooldownSeconds = authState.resendCooldownSeconds;
    final isCooldownActive = cooldownSeconds > 0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3-STEP MINDFUL PASSAGE',
            style: AppTypography.accordionCategory.copyWith(color: accentColor),
          ),
          const SizedBox(height: 16.0),
          _buildStepRow(
            number: '1',
            title: 'Open your inbox',
            description: 'Find the heartfelt verification email sent to ${authState.email.isEmpty ? "your email" : authState.email}.',
            accentColor: accentColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
          ),
          const SizedBox(height: 14.0),
          _buildStepRow(
            number: '2',
            title: 'Tap verification link',
            description: 'Authenticate your device to unlock intentional matching.',
            accentColor: accentColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
          ),
          const SizedBox(height: 14.0),
          _buildStepRow(
            number: '3',
            title: 'Return to your sanctuary',
            description: 'Begin building your authentic, verified persona.',
            accentColor: accentColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
          ),
          const SizedBox(height: 20.0),
          Divider(color: cardBorder, height: 1.0),
          const SizedBox(height: 16.0),
          Center(
            child: isCooldownActive
                ? Text(
                    'Resend link in ${cooldownSeconds}s',
                    style: AppTypography.bodySmall.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      ref
                          .read(authControllerProvider.notifier)
                          .resendVerificationEmail();
                    },
                    child: Text(
                      'Resend Verification Link',
                      style: AppTypography.bodyMedium.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String description,
    required Color accentColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.0,
          height: 24.0,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 1.0),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: bodyColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
