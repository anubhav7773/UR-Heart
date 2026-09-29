import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/auth_controller.dart';

/// 3-Step Live Count Mindful Passage Card
/// Live tracks:
/// Step 1: Secure Link Dispatched
/// Step 2: Live Listening for Email Tap (Real-time elapsed seconds counter)
/// Step 3: Verified & Sacred Sanctuary Entry
class MagicLinkPassageCard extends ConsumerWidget {
  final int currentStep;
  final int elapsedSeconds;
  final String targetEmail;
  final VoidCallback onOpenEmailApp;
  final VoidCallback? onOpenDirectLink;
  final VoidCallback? onCopyLink;
  final VoidCallback onResend;

  const MagicLinkPassageCard({
    super.key,
    required this.currentStep,
    required this.elapsedSeconds,
    required this.targetEmail,
    required this.onOpenEmailApp,
    this.onOpenDirectLink,
    this.onCopyLink,
    required this.onResend,
  });

  String _formatElapsed(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;

    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final accentColor = isDark
        ? DarkSanctuaryTokens.accentTerracotta
        : LightSanctuaryTokens.accentTerracotta;
    final pineColor = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final bodyColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final cooldownSeconds = authState.resendCooldownSeconds;
    final isCooldownActive = cooldownSeconds > 0;

    final double progressPercent = currentStep == 1
        ? 0.33
        : currentStep == 2
            ? 0.66
            : 1.0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Live Progress & Step Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentStep == 3 ? Colors.green : pineColor,
                      boxShadow: [
                        BoxShadow(
                          color: (currentStep == 3 ? Colors.green : pineColor)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE STEP TRACKER',
                    style: AppTypography.accordionCategory.copyWith(
                      color: accentColor,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pineColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pineColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Step $currentStep of 3',
                  style: TextStyle(
                    color: pineColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Animated Linear Step Indicator Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progressPercent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: cardBorder.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    currentStep == 3 ? const Color(0xFF2EC4B6) : pineColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20.0),

          // STEP 1: Link Dispatched
          _buildStepRow(
            number: '1',
            isCompleted: currentStep > 1,
            isActive: currentStep == 1,
            title: 'Sacred Link Dispatched',
            description: 'Encrypted invitation delivered to $targetEmail.',
            statusPill: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Delivered',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            accentColor: accentColor,
            pineColor: pineColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
            cardBorder: cardBorder,
          ),
          const SizedBox(height: 18.0),

          // STEP 2: Live Listening for Email Tap
          _buildStepRow(
            number: '2',
            isCompleted: currentStep > 2,
            isActive: currentStep == 2,
            title: currentStep > 2
                ? 'Email Link Tapped & Verified'
                : 'Open Email & Tap Sacred Link',
            description: currentStep > 2
                ? 'Your device was authenticated via the verification link.'
                : 'Tap the link sent to your inbox. This screen will verify automatically.',
            statusPill: currentStep == 2
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: pineColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pineColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: pineColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Listening: ${_formatElapsed(elapsedSeconds)}',
                          style: TextStyle(
                            color: pineColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : currentStep > 2
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
            actionWidget: currentStep == 2
                ? Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pineColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: onOpenEmailApp,
                            icon: const Icon(Icons.mail_outline, size: 16, color: Colors.white),
                            label: const Text(
                              'Open Email App Now ➔',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (onOpenDirectLink != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 38,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: accentColor, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: onOpenDirectLink,
                              icon: Icon(Icons.open_in_browser, size: 16, color: accentColor),
                              label: Text(
                                'Open Link in Browser Directly ➔',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (onCopyLink != null) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton.icon(
                              onPressed: onCopyLink,
                              icon: Icon(Icons.copy_rounded, size: 13, color: mutedColor),
                              label: Text(
                                'Copy Verification Link',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gmail delay or rate-limit? Tap "Open Link in Browser Directly" above to verify instantly without waiting!',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? const Color(0xFFFFD166) : const Color(0xFF8C5800),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            accentColor: accentColor,
            pineColor: pineColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
            cardBorder: cardBorder,
          ),
          const SizedBox(height: 18.0),

          // STEP 3: Sanctuary Entry & Profile Setup
          _buildStepRow(
            number: '3',
            isCompleted: currentStep == 3,
            isActive: currentStep == 3,
            title: currentStep == 3
                ? 'Welcome to Profile Sanctuary'
                : 'Enter Profile Sanctuary',
            description: currentStep == 3
                ? 'Authenticated! Redirecting to setup your sacred profile...'
                : 'Fill your authentic details and begin mindful connection.',
            statusPill: currentStep == 3
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.celebration, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Instant Entry',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            accentColor: accentColor,
            pineColor: pineColor,
            titleColor: titleColor,
            bodyColor: bodyColor,
            cardBorder: cardBorder,
          ),

          const SizedBox(height: 20.0),
          Divider(color: cardBorder, height: 1.0),
          const SizedBox(height: 14.0),

          // Cooldown and Resend Action
          Center(
            child: isCooldownActive
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: mutedColor),
                      const SizedBox(width: 6),
                      Text(
                        'Resend link in ${cooldownSeconds}s',
                        style: AppTypography.bodySmall.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : TextButton.icon(
                    onPressed: onResend,
                    icon: Icon(Icons.refresh, size: 16, color: accentColor),
                    label: Text(
                      'Resend Verification Link',
                      style: AppTypography.bodyMedium.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required bool isCompleted,
    required bool isActive,
    required String title,
    required String description,
    Widget? statusPill,
    Widget? actionWidget,
    required Color accentColor,
    required Color pineColor,
    required Color titleColor,
    required Color bodyColor,
    required Color cardBorder,
  }) {
    Color iconBg;
    Color iconBorder;
    Widget iconContent;

    if (isCompleted) {
      iconBg = Colors.green.withValues(alpha: 0.15);
      iconBorder = Colors.green;
      iconContent = const Icon(Icons.check, size: 14, color: Colors.green);
    } else if (isActive) {
      iconBg = pineColor.withValues(alpha: 0.2);
      iconBorder = pineColor;
      iconContent = Text(
        number,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: pineColor,
        ),
      );
    } else {
      iconBg = cardBorder.withValues(alpha: 0.3);
      iconBorder = cardBorder;
      iconContent = Text(
        number,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: bodyColor.withValues(alpha: 0.4),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28.0,
          height: 28.0,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
            border: Border.all(color: iconBorder, width: 1.5),
          ),
          child: Center(child: iconContent),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: titleColor,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (statusPill != null) statusPill,
                ],
              ),
              const SizedBox(height: 3.0),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: bodyColor.withValues(alpha: 0.8),
                  height: 1.35,
                ),
              ),
              if (actionWidget != null) actionWidget,
            ],
          ),
        ),
      ],
    );
  }
}
