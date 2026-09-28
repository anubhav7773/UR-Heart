import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/user_profile_model.dart';

/// Card presenting immutable credentials (DOB, Orientation, WhatsApp Enclave)
class LockedCredentialsCard extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;

  const LockedCredentialsCard({
    super.key,
    required this.profile,
    required this.isDark,
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
    final lockBadgeColor = isDark
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
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: lockBadgeColor),
              const SizedBox(width: 8),
              Text(
                'Locked & Protected Credentials',
                style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 1. Date of Birth Verification Pill
          Text(
            'DATE OF BIRTH',
            style: AppTypography.bodySmall.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: lockBadgeColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 15, color: lockBadgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.dobVerificationPill,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: headlineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 2. Orientation & Preference Pills
          Text(
            'ORIENTATION & INTENT',
            style: AppTypography.bodySmall.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildPill(
                icon: Icons.person_outline,
                label: profile.gender.trim().isNotEmpty
                    ? profile.gender.trim()
                    : 'Sanctuary Seeker',
                chipBg: chipBg,
                textColor: headlineColor,
              ),
              const SizedBox(width: 8),
              _buildPill(
                icon: Icons.favorite_border_rounded,
                label: profile.interestedIn.trim().isNotEmpty
                    ? 'Interested in ${profile.interestedIn.trim()}'
                    : 'Seeking Resonances',
                chipBg: chipBg,
                textColor: headlineColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3. WhatsApp Enclave (Masked)
          Text(
            'WHATSAPP ENCLAVE',
            style: AppTypography.bodySmall.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.phonelink_lock_rounded, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.maskedWhatsApp.trim().isNotEmpty
                        ? profile.maskedWhatsApp.trim()
                        : 'Enclave Shield Active',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: headlineColor,
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

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color chipBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
