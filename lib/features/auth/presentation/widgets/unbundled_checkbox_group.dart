import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/consent_controller.dart';

class UnbundledCheckboxGroup extends ConsumerWidget {
  const UnbundledCheckboxGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final consentState = ref.watch(consentControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUTORY AFFIRMATIONS (UNBUNDLED)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: subText,
          ),
        ),
        const SizedBox(height: 12),

        // Affirmation 1: Age Declaration (DPDP Act 2023 Sec 9)
        _buildCheckboxTile(
          context: context,
          value: consentState.isAgeConfirmed,
          title: 'I solemnly confirm I am 18 years of age or older.',
          subtitle: 'Required under Section 9 of the DPDP Act 2023. Underage access is quarantined.',
          onChanged: (val) => ref.read(consentControllerProvider.notifier).toggleAgeConfirmed(val ?? false),
          activeColor: pine,
          textColor: primaryText,
          subTextColor: subText,
        ),
        const SizedBox(height: 8),

        // Affirmation 2: Terms & Community Enclave EULA
        _buildCheckboxTile(
          context: context,
          value: consentState.isEulaAccepted,
          title: 'I accept the Sanctuary Terms of Service & Community EULA.',
          subtitle: 'Mandatory agreement governing mindful conduct and anti-harassment policies.',
          onChanged: (val) => ref.read(consentControllerProvider.notifier).toggleEulaAccepted(val ?? false),
          activeColor: pine,
          textColor: primaryText,
          subTextColor: subText,
        ),
        const SizedBox(height: 8),

        // Affirmation 3: Specific DPDP Act Sec 6 Data Processing Consent
        _buildCheckboxTile(
          context: context,
          value: consentState.isDpdpConsented,
          title: 'I grant specific consent for personal data processing.',
          subtitle: 'Covers discovery match scoring, encrypted contact bridge, and biometric KYC reflection.',
          onChanged: (val) => ref.read(consentControllerProvider.notifier).toggleDpdpConsented(val ?? false),
          activeColor: pine,
          textColor: primaryText,
          subTextColor: subText,
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required BuildContext context,
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool?> onChanged,
    required Color activeColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? activeColor.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor.withValues(alpha: 0.4) : subTextColor.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: subTextColor, height: 1.3),
          ),
        ),
      ),
    );
  }
}
