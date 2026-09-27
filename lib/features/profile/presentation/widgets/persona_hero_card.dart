import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/user_profile_model.dart';

/// Persona Hero Card displaying avatar, name, verified crest, and member since date (< 130 lines)
class PersonaHeroCard extends StatelessWidget {
  final UserProfile? profileData;
  final UserProfile? profile;
  final bool isDark;
  final VoidCallback? onAvatarEditTap;
  final VoidCallback? onEditAvatar;

  const PersonaHeroCard({
    super.key,
    this.profileData,
    this.profile,
    required this.isDark,
    this.onAvatarEditTap,
    this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProfile = profileData ?? profile ?? const UserProfile(
      id: '00000000-0000-0000-0000-000000000000',
      fullName: 'Aarav Sharma',
      email: 'aarav@sanctuary.internal',
      age: 23,
      dobVerificationPill: '14 Oct 2002 · LOCKED & VERIFIED',
      gender: 'Male',
      interestedIn: 'Women',
      maskedWhatsApp: '+91 98765 ***** · ENCRYPTED',
      memberSinceText: 'Member since Oct 2024 · Verified',
      hasVerifiedCrest: true,
      location: 'Bengaluru, India',
      bio: 'Mindful architecture, quiet coffee, and resonant human connections.',
      profession: 'Architect',
      education: 'Master of Design',
      minAgePref: 21,
      maxAgePref: 28,
      avatarUrl: '',
      momentPhotos: <String>[],
    );

    final cardBg = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final crestColor = isDark ? DarkSanctuaryTokens.verifiedBadge : LightSanctuaryTokens.verifiedBadge;
    final onEdit = onAvatarEditTap ?? onEditAvatar ?? () {};

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
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder,
                child: const Icon(Icons.person_rounded, size: 40, color: Colors.grey),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.sanctuaryPine,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${effectiveProfile.fullName}, ${effectiveProfile.age}',
                        style: AppTypography.titleH2.copyWith(color: headlineColor, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: crestColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CREST',
                        style: TextStyle(color: crestColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  effectiveProfile.locationCity,
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Member since Oct 2024 · Verified',
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
