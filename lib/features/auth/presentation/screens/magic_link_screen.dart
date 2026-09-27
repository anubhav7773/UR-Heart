import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/magic_link_passage_card.dart';

/// Screen 3: Magic Link Verification Passage
/// Guides user through mindful email verification with cooldown protection
class MagicLinkScreen extends ConsumerWidget {
  const MagicLinkScreen({super.key});

  static const String routeName = '/verify-email';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;

    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;

    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final emailToDisplay =
        authState.email.isEmpty ? 'your sanctuary inbox' : authState.email;

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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12.0),
              // Glowing Letter Icon
              Container(
                width: 80.0,
                height: 80.0,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                  child: Icon(Icons.mark_email_unread_outlined, size: 36.0, color: accentColor),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Almost home.',
                textAlign: TextAlign.center,
                style: AppTypography.titleH2.copyWith(color: titleColor),
              ),
              Text(
                'Verify your sanctuary.',
                textAlign: TextAlign.center,
                style: AppTypography.titleH1Italic.copyWith(
                  fontSize: 22.0,
                  color: isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent,
                ),
              ),
              const SizedBox(height: 20.0),
              // Email Summary Card with Edit Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, size: 18.0, color: mutedColor),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        emailToDisplay,
                        style: AppTypography.bodySmall.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Edit',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
              // 3-Step Passage Card
              const MagicLinkPassageCard(),
              const SizedBox(height: 24.0),
              // Primary Button
              SizedBox(
                width: double.infinity,
                height: 52.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.0)),
                  ),
                  onPressed: () {
                    // Simulates opening email app & confirms deep link passage
                    ref.read(authControllerProvider.notifier).simulateMagicLinkConfirmation();
                    Navigator.of(context).pushNamed('/profile-setup');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Open Email App', style: AppTypography.buttonPrimary.copyWith(color: Colors.white)),
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
