import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// Mindful Bio Editor featuring EVA AI Polish button, Profession, and Education
class MindfulBioEditor extends ConsumerStatefulWidget {
  const MindfulBioEditor({super.key});

  @override
  ConsumerState<MindfulBioEditor> createState() => _MindfulBioEditorState();
}

class _MindfulBioEditorState extends ConsumerState<MindfulBioEditor> {
  late TextEditingController _bioController;
  late TextEditingController _professionController;
  late TextEditingController _educationController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(profileSetupControllerProvider);
    _bioController = TextEditingController(text: state.bio);
    _professionController = TextEditingController(text: state.profession);
    _educationController = TextEditingController(text: state.education);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _professionController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileSetupControllerProvider);
    final notifier = ref.read(profileSetupControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    // Sync if state updated by EVA AI polish
    if (_bioController.text != profileState.bio && !profileState.isPolishingBio) {
      _bioController.text = profileState.bio;
    }

    final inputBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;

    final inputBorder = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;

    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MINDFUL BIO (MAX 500 CHARS)',
                style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
            TextButton.icon(
              onPressed: profileState.isPolishingBio
                  ? null
                  : () async {
                      await notifier.polishBioWithEvaAi(_bioController.text.trim());
                    },
              icon: profileState.isPolishingBio
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: accentColor),
                    )
                  : Icon(Icons.auto_awesome, size: 14.0, color: accentColor),
              label: Text(
                'EVA AI Polish ✨',
                style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: inputBorder),
          ),
          child: TextField(
            controller: _bioController,
            maxLength: 500,
            maxLines: 3,
            style: TextStyle(color: textColor, fontSize: 13.5, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Share intentional thoughts, quiet passions, or what resonates with you...',
              hintStyle: TextStyle(color: mutedColor, fontSize: 13.0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14.0),
              counterStyle: TextStyle(color: mutedColor, fontSize: 11.0),
            ),
            onChanged: notifier.setBio,
          ),
        ),
        const SizedBox(height: 14.0),
        Row(
          children: [
            Expanded(
              child: _buildShortField(
                label: 'PROFESSION',
                hintText: 'e.g. Architect, Designer',
                controller: _professionController,
                inputBg: inputBg,
                inputBorder: inputBorder,
                textColor: textColor,
                mutedColor: mutedColor,
                onChanged: notifier.setProfession,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: _buildShortField(
                label: 'EDUCATION',
                hintText: 'e.g. Design Institute / Self-taught',
                controller: _educationController,
                inputBg: inputBg,
                inputBorder: inputBorder,
                textColor: textColor,
                mutedColor: mutedColor,
                onChanged: notifier.setEducation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required Color inputBg,
    required Color inputBorder,
    required Color textColor,
    required Color mutedColor,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
        const SizedBox(height: 6.0),
        Container(
          height: 46.0,
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: inputBorder),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: textColor, fontSize: 13.0),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: mutedColor.withOpacity(0.6), fontSize: 12.0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
