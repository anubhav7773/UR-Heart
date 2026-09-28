import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/widgets/theme_selector_pill.dart';
import '../controllers/consent_controller.dart';
import '../widgets/consent_accordion_group.dart';
import '../widgets/unbundled_checkbox_group.dart';

/// Screen 1: Mindful Consent & Statutory Legal Gateway
/// Features bilingual DPDP Act 2023 unbundled consent and permanent theme locking
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  static const String routeName = '/consent';

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isSetupDone = prefs.getBool('ur_heart_profile_setup_completed') ?? false;
        final hasAuth = (prefs.getString('ur_heart_auth_token')?.isNotEmpty ?? false) ||
                        (prefs.getString('auth_token')?.isNotEmpty ?? false) ||
                        (prefs.getString('ur_heart_user_email')?.isNotEmpty ?? false);
        final isConsentGiven = (prefs.getBool('urheart_theme_permanently_locked') ?? false) ||
                               (prefs.getBool('ur_heart_theme_locked') ?? false) ||
                               (prefs.getBool('ur_heart_consent_given') ?? false);

        if (!mounted) return;
        if (hasAuth && isSetupDone) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else if (hasAuth && !isSetupDone) {
          Navigator.of(context).pushReplacementNamed('/profile-setup');
        } else if (isConsentGiven) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final consentState = ref.watch(consentProvider);
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;

    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final italicColor = isDark
        ? DarkSanctuaryTokens.textHeadlineItalic
        : LightSanctuaryTokens.textHeadlineItalic;

    final subtitleColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;

    final cornerTextColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final primaryButtonBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leadingWidth: 120,
        leading: Center(
          child: Text(
            'More than swipes',
            style: AppTypography.caption.copyWith(color: cornerTextColor),
          ),
        ),
        centerTitle: true,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: ThemeSelectorPill(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Safer · Kinder · Real',
                style: AppTypography.caption.copyWith(color: cornerTextColor),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12.0),
              // App Crest Icon
              Icon(
                Icons.favorite_rounded,
                size: 38.0,
                color: italicColor,
              ),
              const SizedBox(height: 12.0),
              Text(
                'Mindful consent.',
                textAlign: TextAlign.center,
                style: AppTypography.titleH1.copyWith(color: titleColor),
              ),
              Text(
                'Real trust.',
                textAlign: TextAlign.center,
                style: AppTypography.titleH1Italic.copyWith(color: italicColor),
              ),
              const SizedBox(height: 10.0),
              Text(
                'UR-Heart is a deliberate sanctuary where real people build intentional connections without algorithms racing your heart.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: subtitleColor, height: 1.45),
              ),
              const SizedBox(height: 20.0),
              const ConsentAccordionGroup(),
              const SizedBox(height: 16.0),
              // Unbundled Affirmative Checkboxes
              const UnbundledCheckboxGroup(),
              const SizedBox(height: 24.0),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonBg,
                    disabledBackgroundColor: primaryButtonBg.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27.0),
                    ),
                    elevation: consentState.canProceed ? 4.0 : 0.0,
                  ),
                  onPressed: consentState.canProceed
                      ? () async {
                          await ref.read(consentProvider.notifier).submitConsent();
                          if (context.mounted) {
                            Navigator.of(context).pushNamed('/auth');
                          }
                        }
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'I Agree & Continue',
                        style: AppTypography.buttonPrimary.copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: 8.0),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 18.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }
}
