import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/profile_setup_controller.dart';

/// Gender dropdown and Interested In selector pills
class OrientationSelectorPills extends ConsumerWidget {
  const OrientationSelectorPills({super.key});

  static const List<String> _genders = ['Woman', 'Man', 'Non-binary'];
  static const List<String> _interestedOptions = ['Men', 'Women', 'Everyone'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupControllerProvider);
    final notifier = ref.read(profileSetupControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final inputBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;

    final inputBorder = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;

    final activePillBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final inactivePillBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.chipBackground;

    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gender Selector
        Text('GENDER IDENTITY',
            style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
        const SizedBox(height: 6.0),
        Container(
          height: 46.0,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.gender,
              dropdownColor: inputBg,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: mutedColor),
              items: _genders.map((g) {
                return DropdownMenuItem<String>(
                  value: g,
                  child: Text(g, style: TextStyle(color: textColor, fontSize: 13.5)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) notifier.setGender(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 14.0),
        // Interested In Multi-Select Pills
        Text('INTERESTED IN RESONATING WITH',
            style: AppTypography.accordionCategory.copyWith(color: mutedColor)),
        const SizedBox(height: 8.0),
        Row(
          children: _interestedOptions.map((opt) {
            final isSelected = state.interestedIn.contains(opt);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(20.0),
                onTap: () => notifier.toggleInterestedIn(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: isSelected ? activePillBg : inactivePillBg,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isSelected ? activePillBg : inputBorder,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : textColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
