import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Policy-safe Night Sanctuary Slumber toggle card
/// AdMob IVT compliant: Guaranteed zero automatic video loops in the background
class NightSlumberToggleCard extends StatelessWidget {
  final bool isSlumberActive;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onSimulatePickup;
  final bool isDark;

  const NightSlumberToggleCard({
    super.key,
    required this.isSlumberActive,
    required this.onChanged,
    this.onSimulatePickup,
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
    final safeBadgeColor = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

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
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bedtime_outlined, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Night Sanctuary Slumber',
                      style: AppTypography.titleH2.copyWith(
                        color: headlineColor,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Rest your device face-down overnight. Wake up to a mindful visual harvest.',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isSlumberActive,
                activeColor: accentColor,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.shield_outlined, color: safeBadgeColor, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Policy-safe architecture: Zero background ad loops. Claims occur on morning wake.',
                  style: AppTypography.caption.copyWith(
                    color: safeBadgeColor,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (isSlumberActive && onSimulatePickup != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onSimulatePickup,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Wake Sensor ☀️',
                    style: AppTypography.caption.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
