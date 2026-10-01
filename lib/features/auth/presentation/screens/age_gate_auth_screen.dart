import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../profile_setup/presentation/controllers/profile_setup_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_credential_field.dart';
import '../widgets/auth_tab_switcher.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/neutral_dob_wheel.dart';
import '../widgets/verified_adult_badge.dart';

/// Screen 2: Sanctuary Age Gate & Authentication
/// Strictly enforces Google Play minor exclusion (18+) via neutral DOB selection
/// and provides 100% production-grade Google One Tap / Sign-In.
class AgeGateAuthScreen extends ConsumerWidget {
  const AgeGateAuthScreen({super.key});

  static const String routeName = '/auth';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final subtitleColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;
    final inputBg = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;
    final inputBorder = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;
    final primaryButtonBg = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Real people. Real resonance.',
                  style: AppTypography.titleH2.copyWith(color: titleColor)),
              const SizedBox(height: 6.0),
              Text('Connection starts with showing up as yourself.',
                  style: AppTypography.bodySmall.copyWith(color: subtitleColor)),
              const SizedBox(height: 16.0),
              // Strict 18+ Global Gatekeeper (Mandatory for ALL users)
              const NeutralDobWheel(),
              const VerifiedAdultBadge(),
              const SizedBox(height: 18.0),
              AuthTabSwitcher(
                isSignIn: authState.isSignInTab,
                isDark: isDark,
                onChanged: (val) => authNotifier.setAuthTab(isSignIn: val),
              ),
              const SizedBox(height: 18.0),
              AuthCredentialField(
                label: 'EMAIL ADDRESS',
                hintText: 'Enter your email',
                inputBg: inputBg,
                inputBorder: inputBorder,
                textColor: titleColor,
                mutedColor: mutedColor,
                keyboardType: TextInputType.emailAddress,
                onChanged: authNotifier.setEmail,
              ),
              const SizedBox(height: 14.0),
              AuthCredentialField(
                label: 'PASSWORD',
                hintText: 'Minimum 6 characters',
                inputBg: inputBg,
                inputBorder: inputBorder,
                textColor: titleColor,
                mutedColor: mutedColor,
                obscureText: !authState.isPasswordVisible,
                onChanged: authNotifier.setPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    authState.isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: mutedColor,
                    size: 20.0,
                  ),
                  onPressed: authNotifier.togglePasswordVisibility,
                ),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 12.0),
                Text(
                  authState.errorMessage ?? '',
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFFE63946),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24.0),
              SizedBox(
                width: double.infinity,
                height: 52.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonBg,
                    disabledBackgroundColor: primaryButtonBg.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.0),
                    ),
                  ),
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          // Strict 18+ Gatekeeper Validation
                          if (!authState.hasSelectedFullDob || !authState.isAdult) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Strict 18+ Age Gate: Please select your Date of Birth above and confirm you are 18+ to proceed.',
                                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          if (!authState.canSubmit) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a valid email and minimum 6-character password.',
                                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFFC94A29),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          if (authState.isSignInTab) {
                            // --- EXISTING USER SIGN IN ---
                            final result = await authNotifier.signInWithPassword();
                            if (result.isSuccess && context.mounted) {
                              await ref
                                  .read(profileSetupControllerProvider.notifier)
                                  .loadSavedProfile();
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Text(
                                        'Welcome back to your Sanctuary ✨',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF1B4332),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              if (result.isProfileCompleted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/main',
                                  (route) => false,
                                );
                              } else {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/profile-setup',
                                  (route) => false,
                                );
                              }
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.errorMessage ?? 'Sign In failed. Please check your credentials.',
                                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: const Color(0xFFC94A29),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            // --- NEW ACCOUNT REGISTRATION ---
                            final success = await authNotifier.submitRegistration();
                            if (success && context.mounted) {
                              Navigator.of(context).pushNamed(
                                '/verify-email',
                                arguments: {'email': authState.email},
                              );
                            }
                          }
                        },

                  child: authState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Enter Sanctuary ➔',
                          style: AppTypography.buttonPrimary.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16.0),
              Center(child: Text('or quietly with', style: AppTypography.caption.copyWith(color: mutedColor))),
              const SizedBox(height: 12.0),
              GoogleSignInButton(
                isDark: isDark,
                isLoading: authState.isGoogleLoading,
                onPressed: () async {
                  // Strict 18+ Gatekeeper Validation for One Tap / Google Sign In
                  if (!authState.hasSelectedFullDob || !authState.isAdult) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Strict 18+ Age Gate: Please select your Date of Birth above and confirm you are 18+ before continuing with Google.',
                          style: AppTypography.bodySmall.copyWith(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFFC94A29),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final result = await authNotifier.signInWithGoogle();
                  if (result.isSuccess && context.mounted) {
                    if (result.displayName != null &&
                        result.displayName!.isNotEmpty) {
                      ref
                          .read(profileSetupControllerProvider.notifier)
                          .setFullName(result.displayName!);
                    }
                    await ref
                        .read(profileSetupControllerProvider.notifier)
                        .loadSavedProfile();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Welcome, ${result.displayName ?? "Soul Seeker"} ✨',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF1B4332),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    // Route returning users directly to main app
                    if (result.isProfileCompleted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/main',
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pushNamed('/profile-setup');
                    }
                  }
                },
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
