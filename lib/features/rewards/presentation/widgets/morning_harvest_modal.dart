import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Interactive wake-up reward claim dialog triggered upon morning pickup (< 150 lines)
class MorningHarvestModal extends StatelessWidget {
  final VoidCallback? onWatchClaimAd;
  final VoidCallback? onClaimHarvestTapped;
  final bool isDark;

  const MorningHarvestModal({
    super.key,
    this.onWatchClaimAd,
    this.onClaimHarvestTapped,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.sanctuaryPine;
    final bodyColor = isDark ? DarkSanctuaryTokens.textBody : LightSanctuaryTokens.textBody;
    const buttonTextColor = Colors.white;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wb_sunny_outlined, color: accentColor, size: 40.0),
            ),
            const SizedBox(height: 20.0),
            Text(
              'Morning Harvest Greeting',
              textAlign: TextAlign.center,
              style: AppTypography.titleH2.copyWith(color: headlineColor, fontSize: 20.0),
            ),
            const SizedBox(height: 10.0),
            Text(
              'Your device rested quietly overnight. Complete 1 mindful interactive sponsor reflection to unmask your morning harvest (+20 Swipes & +2 Direct Letters).',
              textAlign: TextAlign.center,
              style: TextStyle(color: bodyColor, height: 1.45, fontSize: 13.0),
            ),
            const SizedBox(height: 22.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: buttonTextColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  final cb = onClaimHarvestTapped ?? onWatchClaimAd;
                  if (cb != null) cb();
                },
                child: const Text(
                  'Claim Morning Harvest',
                  style: TextStyle(color: buttonTextColor, fontWeight: FontWeight.w700, fontSize: 14.0),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Later',
                style: TextStyle(
                  color: isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted,
                  fontSize: 12.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
