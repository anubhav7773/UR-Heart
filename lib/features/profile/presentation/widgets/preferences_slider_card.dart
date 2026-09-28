import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/user_profile_model.dart';

/// Card for customizable persona philosophy, location, profession, age slider
class PreferencesSliderCard extends StatefulWidget {
  final UserProfile profile;
  final bool isDark;
  final bool isPolishing;
  final bool isSaving;
  final VoidCallback onUpdateGps;
  final VoidCallback onPolishBio;
  final void Function(String bio) onBioChanged;
  final void Function(String profession) onProfessionChanged;
  final void Function(String education) onEducationChanged;
  final void Function(double min, double max) onAgeRangeChanged;
  final VoidCallback onSaveChanges;

  const PreferencesSliderCard({
    super.key,
    required this.profile,
    required this.isDark,
    required this.isPolishing,
    required this.isSaving,
    required this.onUpdateGps,
    required this.onPolishBio,
    required this.onBioChanged,
    required this.onProfessionChanged,
    required this.onEducationChanged,
    required this.onAgeRangeChanged,
    required this.onSaveChanges,
  });

  @override
  State<PreferencesSliderCard> createState() => _PreferencesSliderCardState();
}

class _PreferencesSliderCardState extends State<PreferencesSliderCard> {
  late TextEditingController _bioController;
  late TextEditingController _profController;
  late TextEditingController _eduController;
  late RangeValues _ageRange;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
    _profController = TextEditingController(text: widget.profile.profession);
    _eduController = TextEditingController(text: widget.profile.education);
    _ageRange = RangeValues(widget.profile.minAgePref, widget.profile.maxAgePref);
  }

  @override
  void didUpdateWidget(covariant PreferencesSliderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile.bio != _bioController.text) {
      _bioController.text = widget.profile.bio;
    }
    if (widget.profile.profession != _profController.text) {
      _profController.text = widget.profile.profession;
    }
    if (widget.profile.education != _eduController.text) {
      _eduController.text = widget.profile.education;
    }
    if (oldWidget.profile.minAgePref != widget.profile.minAgePref ||
        oldWidget.profile.maxAgePref != widget.profile.maxAgePref) {
      _ageRange = RangeValues(widget.profile.minAgePref, widget.profile.maxAgePref);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _profController.dispose();
    _eduController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = widget.isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = widget.isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = widget.isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final inputBg = widget.isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;
    final accentColor = widget.isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

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
          Text('Philosophy & Sanctuary Details',
              style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor)),
          const SizedBox(height: 12),
          // Location & GPS Update
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SANCTUARY LOCATION',
                  style: AppTypography.bodySmall.copyWith(
                      color: mutedColor, fontWeight: FontWeight.w600, fontSize: 11)),
              TextButton.icon(
                onPressed: widget.onUpdateGps,
                icon: const Icon(Icons.my_location_rounded, size: 14),
                label: const Text('Update GPS', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          // Mindful Bio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MINDFUL BIO (MAX 500)',
                  style: AppTypography.bodySmall.copyWith(
                      color: mutedColor, fontWeight: FontWeight.w600, fontSize: 11)),
              TextButton.icon(
                onPressed: widget.isPolishing ? null : widget.onPolishBio,
                icon: widget.isPolishing
                    ? const SizedBox(
                        width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: Text(widget.isPolishing ? 'Refining...' : 'EVA AI Polish ✨',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          TextField(
            controller: _bioController,
            maxLength: 500,
            maxLines: 3,
            onChanged: widget.onBioChanged,
            style: TextStyle(fontSize: 13, color: headlineColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          _buildFieldHeader('PROFESSION', mutedColor),
          TextField(
            controller: _profController,
            onChanged: widget.onProfessionChanged,
            style: TextStyle(fontSize: 13, color: headlineColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldHeader('EDUCATION', mutedColor),
          TextField(
            controller: _eduController,
            onChanged: widget.onEducationChanged,
            style: TextStyle(fontSize: 13, color: headlineColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldHeader('PREFERRED AGE RANGE', mutedColor),
              Text(
                '${_ageRange.start.round()} - ${_ageRange.end.round()} yrs',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: headlineColor),
              ),
            ],
          ),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 35,
            divisions: 17,
            activeColor: accentColor,
            onChanged: (vals) {
              setState(() => _ageRange = vals);
              widget.onAgeRangeChanged(vals.start, vals.end);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isSaving ? null : widget.onSaveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: widget.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes ➔',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String title, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title,
          style: AppTypography.bodySmall
              .copyWith(color: mutedColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}
