import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/user_profile_model.dart';

/// Card for customizable persona philosophy, location, and age slider (< 160 lines)
class PersonaPreferencesCard extends StatefulWidget {
  final UserProfile? profileData;
  final UserProfile? profile;
  final bool isDark;
  final VoidCallback? onSaveTap;
  final VoidCallback? onSaveChanges;

  const PersonaPreferencesCard({
    super.key,
    this.profileData,
    this.profile,
    required this.isDark,
    this.onSaveTap,
    this.onSaveChanges,
  });

  @override
  State<PersonaPreferencesCard> createState() => _PersonaPreferencesCardState();
}

class _PersonaPreferencesCardState extends State<PersonaPreferencesCard> {
  late TextEditingController _bioController;
  late RangeValues _ageRange;

  UserProfile get _profile =>
      widget.profileData ??
      widget.profile ??
      const UserProfile(
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

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: _profile.bio);
    _ageRange = RangeValues(_profile.minAgePref, _profile.maxAgePref);
  }

  @override
  void didUpdateWidget(covariant PersonaPreferencesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_profile.bio != _bioController.text) {
      _bioController.text = _profile.bio;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final cardBorder = widget.isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = widget.isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final mutedColor = widget.isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pineColor = widget.isDark ? DarkSanctuaryTokens.secondaryPine : LightSanctuaryTokens.primaryPine;
    final coralColor = widget.isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent;

    final onSave = widget.onSaveTap ?? widget.onSaveChanges ?? () {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mindful Philosophy (Bio)',
                style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
              ),
              Text(
                'Groq AI LPU Polish ✨',
                style: TextStyle(fontSize: 11, color: coralColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 3,
            style: TextStyle(color: headlineColor, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.isDark ? DarkSanctuaryTokens.inputBackground : LightSanctuaryTokens.chipBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Discovery Age Resonance: ${_ageRange.start.round()} – ${_ageRange.end.round()}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: headlineColor),
          ),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 50,
            divisions: 32,
            activeColor: pineColor,
            inactiveColor: cardBorder,
            onChanged: (vals) => setState(() => _ageRange = vals),
          ),
          Text(
            'Applies to discoverable resonance deck.',
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pineColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onSave,
              child: const Text(
                'Save Changes ➔',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
