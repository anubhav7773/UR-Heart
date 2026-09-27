import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Referral card inviting kindred souls with WhatsApp deep-link integration (< 130 lines)
class SacredKinshipCard extends StatelessWidget {
  final String referralCode;
  final bool isDark;

  const SacredKinshipCard({
    super.key,
    required this.referralCode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.sanctuaryPine;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final codeBoxBg = isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground;
    final greenButtonColor = isDark ? DarkSanctuaryTokens.verifiedBadge : LightSanctuaryTokens.verifiedBadge;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diversity_1_outlined, color: accentColor, size: 22.0),
              const SizedBox(width: 10.0),
              Text('Sacred Kinship Referral', style: AppTypography.titleH2.copyWith(color: headlineColor, fontSize: 17.0)),
            ],
          ),
          const SizedBox(height: 5.0),
          Text(
            'Share the sanctuary with kindred spirits. When they enter, both receive 20 bonus reflections.',
            style: TextStyle(color: mutedColor, fontSize: 12.0),
          ),
          const SizedBox(height: 14.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(color: codeBoxBg, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: borderColor, width: 0.8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralCode,
                    style: TextStyle(color: accentColor, fontSize: 17.0, letterSpacing: 2.0, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Referral code $referralCode copied.')));
                  },
                  icon: const Icon(Icons.copy_outlined, size: 15.0),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(foregroundColor: headlineColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: greenButtonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              onPressed: () {
                final text = Uri.encodeComponent('Join me in UR-Heart Sanctuary. Kinship code: $referralCode https://urheart.app/join');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening WhatsApp invitation: https://wa.me/?text=$text')));
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 16.0),
              label: const Text('Invite via WhatsApp', style: TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
