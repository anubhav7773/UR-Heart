import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Interactive Privacy Card: Sacred Photo Veil (Bilateral Consent Photo Shield)
/// Protects against secondary-device photography and unauthorized gaze by blurring
/// feed photos until bilateral mutual consent is granted.
class SacredPhotoVeilCard extends StatelessWidget {
  final bool isVeiled;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final EdgeInsetsGeometry? margin;

  const SacredPhotoVeilCard({
    super.key,
    required this.isVeiled,
    required this.onChanged,
    required this.isDark,
    this.margin,
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
    final accentCoral = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final verifiedTeal = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVeiled
              ? accentCoral.withValues(alpha: 0.4)
              : cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isVeiled
                      ? accentCoral.withValues(alpha: 0.15)
                      : verifiedTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isVeiled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: isVeiled ? accentCoral : verifiedTeal,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Sacred Photo Veil',
                            style: AppTypography.titleH2.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: headlineColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVeiled
                                ? accentCoral.withValues(alpha: 0.15)
                                : verifiedTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isVeiled ? 'VEILED 🔒' : 'CLEAR ✨',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isVeiled ? accentCoral : verifiedTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Anti-Spy Analog Shield: Keep your photos softly blurred across discovery feeds until mutual consent is exchanged.',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: isVeiled,
                activeColor: accentCoral,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  onChanged(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? DarkSanctuaryTokens.inputBackground
                  : LightSanctuaryTokens.inputBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isVeiled ? Icons.shield_outlined : Icons.info_outline_rounded,
                  size: 16,
                  color: isVeiled ? accentCoral : mutedColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVeiled
                        ? 'Protected: Clear photos will unlock only when both seekers mutually agree or match.'
                        : 'Standard: Your verified photos appear clearly to compatible seekers in their feed.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isVeiled ? headlineColor : mutedColor,
                      fontWeight: isVeiled ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
