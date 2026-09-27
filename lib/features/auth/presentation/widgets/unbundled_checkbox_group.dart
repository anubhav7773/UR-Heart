import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/consent_controller.dart';

/// Group of unbundled, affirmative checkboxes mandated by DPDP Act 2023 Sec 6
class UnbundledCheckboxGroup extends ConsumerWidget {
  const UnbundledCheckboxGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentState = ref.watch(consentProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final activeColor = isDark
        ? DarkSanctuaryTokens.checkboxActive
        : LightSanctuaryTokens.checkboxActive;

    final textColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;

    final borderColor = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;

    return Column(
      children: [
        _buildCheckboxTile(
          context: context,
          value: consentState.isAgeConfirmed,
          onChanged: (val) => ref
              .read(consentProvider.notifier)
              .toggleAgeConfirmed(val ?? false),
          text:
              'I confirm that I am at least 18 years old and agree to the Terms of Service & Community EULA.',
          activeColor: activeColor,
          borderColor: borderColor,
          textColor: textColor,
        ),
        const SizedBox(height: 12.0),
        _buildCheckboxTile(
          context: context,
          value: consentState.isDpdpConsented,
          onChanged: (val) => ref
              .read(consentProvider.notifier)
              .toggleDpdpConsented(val ?? false),
          text:
              'I provide explicit, affirmative consent under the DPDP Act 2023 for UR-Heart to process my sanctuary data.',
          activeColor: activeColor,
          borderColor: borderColor,
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
    required Color activeColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24.0,
            height: 24.0,
            child: Checkbox(
              value: value,
              activeColor: activeColor,
              checkColor: Colors.white,
              side: BorderSide(color: borderColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
