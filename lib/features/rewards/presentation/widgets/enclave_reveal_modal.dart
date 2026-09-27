import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Bilateral progress modal showing dual-sided WhatsApp unlock state
class EnclaveRevealModal extends StatelessWidget {
  final int userProgress;
  final int peerProgress;
  final String matchName;
  final bool isUnlocked;
  final VoidCallback onWatchRevealAd;
  final VoidCallback onOpenWhatsApp;
  final bool isDark;

  const EnclaveRevealModal({
    super.key,
    required this.userProgress,
    required this.peerProgress,
    required this.matchName,
    required this.isUnlocked,
    required this.onWatchRevealAd,
    required this.onOpenWhatsApp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final greenColor = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;
    final bothComplete = isUnlocked || (userProgress >= 3 && peerProgress >= 3);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enclave Reveal Ritual',
                  style: AppTypography.titleH2.copyWith(
                    color: headlineColor,
                    fontSize: 20.0,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: mutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildBilateralRow(accentColor, headlineColor, mutedColor, greenColor, bothComplete),
            const SizedBox(height: 18),
            Text(
              bothComplete ? 'Sacred Enclave Unlocked' : 'Bilateral Intention Required',
              textAlign: TextAlign.center,
              style: AppTypography.titleH2.copyWith(
                color: bothComplete ? greenColor : headlineColor,
                fontSize: 18.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bothComplete
                  ? 'Both souls have completed the 3-step ritual. The 24-hour ephemeral WhatsApp bridge is now illuminated.'
                  : 'Both you and $matchName must complete 3 reflections to safely reveal each other\'s sacred WhatsApp presence.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: mutedColor, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildActionButton(context, accentColor, greenColor, bothComplete),
          ],
        ),
      ),
    );
  }

  Widget _buildBilateralRow(
    Color accent,
    Color headline,
    Color muted,
    Color green,
    bool bothComplete,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.inputBackground,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildParticipantRing('You', userProgress, accent, headline, muted),
          Column(
            children: [
              Icon(bothComplete ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: bothComplete ? green : accent, size: 24),
              const SizedBox(height: 4),
              Text(
                bothComplete ? 'UNLOCKED' : 'BILATERAL',
                style: AppTypography.caption.copyWith(
                  color: bothComplete ? green : muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          _buildParticipantRing(matchName, peerProgress, accent, headline, muted),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Color accent, Color green, bool bothComplete) {
    if (bothComplete) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: green,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onOpenWhatsApp();
          },
          icon: const Icon(Icons.lock_open, color: Colors.white, size: 18),
          label: Text('Open WhatsApp Directly ➔',
              style: AppTypography.buttonPrimary.copyWith(color: Colors.white)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          onWatchRevealAd();
        },
        child: Text(
          userProgress >= 3
              ? 'Awaiting $matchName\'s Progress ($peerProgress/3)'
              : 'Watch 30s Reflection (+1 Step)',
          style: AppTypography.buttonPrimary.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildParticipantRing(
      String label, int progress, Color accent, Color headline, Color muted) {
    final ratio = (progress / 3.0).clamp(0.0, 1.0);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 4.0,
                backgroundColor: muted.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            Text('$progress/3',
                style: AppTypography.buttonPrimary.copyWith(
                  color: headline,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.caption.copyWith(color: muted, fontSize: 11.0)),
      ],
    );
  }
}
