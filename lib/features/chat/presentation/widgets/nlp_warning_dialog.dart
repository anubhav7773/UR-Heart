import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/nlp_chat_sanitizer.dart';

/// Mindful modal explaining the off-platform contact restriction policy
class NlpWarningDialog extends StatelessWidget {
  final SanitizationResult result;
  final bool isDark;
  final VoidCallback onDismiss;

  const NlpWarningDialog({
    super.key,
    required this.result,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final bodyColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;
    final warningColor = isDark
        ? DarkSanctuaryTokens.warningText
        : LightSanctuaryTokens.warningText;
    final buttonBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                color: isDark ? DarkSanctuaryTokens.alertBanner : LightSanctuaryTokens.alertBanner,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, color: warningColor, size: 26.0),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Off-Platform Boundary',
              style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 17.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10.0),
            Text(
              result.userFriendlyMessage ??
                  'Direct contact sharing is restricted to maintain user safety and accountability under DPDP Act 2023.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: bodyColor, height: 1.4),
            ),
            const SizedBox(height: 18.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                child: const Text(
                  'Understood · Keep in Sanctuary',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
