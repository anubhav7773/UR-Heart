import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/settings_models.dart';

/// Card for Incognito Ghost Cloak and Curve25519 cryptographic key rotation
class DiscoveryPrivacyCard extends StatelessWidget {
  final SanctuarySettings? settings;
  final bool? isIncognito;
  final bool isDark;
  final bool isRotatingKey;
  final ValueChanged<bool>? onIncognitoChanged;
  final ValueChanged<bool>? onToggleIncognito;
  final VoidCallback? onRotateKey;
  final VoidCallback? onRotateKeys;

  const DiscoveryPrivacyCard({
    super.key,
    this.settings,
    this.isIncognito,
    required this.isDark,
    this.isRotatingKey = false,
    this.onIncognitoChanged,
    this.onToggleIncognito,
    this.onRotateKey,
    this.onRotateKeys,
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
        : LightSanctuaryTokens.terracottaAccent;
    final verifiedBadge = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;
    final chipBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.chipBackground;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy & Discovery Vault',
            style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
          ),
          const SizedBox(height: 12),
          // 1. Incognito Stream Radius (Ghost Cloak)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Incognito Ghost Cloak',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: headlineColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isIncognito ?? settings?.isIncognito ?? false)
                                ? accentColor.withValues(alpha: 0.15)
                                : verifiedBadge.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (isIncognito ?? settings?.isIncognito ?? false) ? 'HIDDEN' : 'VISIBLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: (isIncognito ?? settings?.isIncognito ?? false) ? accentColor : verifiedBadge,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'When enabled, your profile is removed from the public feed deck entirely.',
                      style: AppTypography.bodySmall.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: isIncognito ?? settings?.isIncognito ?? false,
                activeColor: accentColor,
                onChanged: (val) {
                  final cb = onToggleIncognito ?? onIncognitoChanged;
                  if (cb != null) cb(val);
                },
              ),
            ],
          ),
          const Divider(height: 24),
          // 2. Cryptographic Key Rotation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cryptographic Key Rotation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: headlineColor,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isRotatingKey
                        ? null
                        : () {
                            final cb = onRotateKeys ?? onRotateKey;
                            if (cb != null) cb();
                          },
                    icon: isRotatingKey
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(
                      isRotatingKey ? 'Rotating...' : 'Re-key ⟳',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Generates a fresh ephemeral Curve25519 keypair for 1:1 message ratcheting.',
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 14, color: mutedColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Key: ${settings?.activeKeyFingerprint ?? 'CURVE25519-7F89-SANCTUARY'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: headlineColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
