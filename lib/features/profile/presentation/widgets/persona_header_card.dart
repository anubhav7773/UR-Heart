import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/user_profile_model.dart';

/// Header card displaying user avatar, name, age, crest badge, and member since date
class PersonaHeaderCard extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;
  final VoidCallback onEditAvatar;

  const PersonaHeaderCard({
    super.key,
    required this.profile,
    required this.isDark,
    required this.onEditAvatar,
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
    final crestColor = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        children: [
          // Circular Avatar with Edit Pencil Badge
          Stack(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: isDark
                    ? DarkSanctuaryTokens.secondaryPine
                    : LightSanctuaryTokens.chipBackground,
                child: Text(
                  profile.fullName.isNotEmpty ? profile.fullName[0] : 'U',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEditAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DarkSanctuaryTokens.primaryCoral
                          : LightSanctuaryTokens.terracottaAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Name, Age, Crest & Join Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${profile.fullName}, ${profile.age}',
                        style: AppTypography.titleH2.copyWith(color: headlineColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.hasVerifiedCrest) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Verified Sanctuary Member · Live KYC Confirmed',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: crestColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: crestColor, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 13, color: crestColor),
                              const SizedBox(width: 3),
                              Text(
                                'CREST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: crestColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.memberSinceText,
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: mutedColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.location,
                        style: AppTypography.bodySmall.copyWith(color: mutedColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
