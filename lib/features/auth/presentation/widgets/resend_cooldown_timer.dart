import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/sanctuary_typography.dart';
import '../controllers/auth_controller.dart';

class ResendCooldownTimer extends ConsumerWidget {
  final VoidCallback? onResend;

  const ResendCooldownTimer({super.key, this.onResend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final muted = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final accent = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine;

    final seconds = authState.resendCooldownSeconds;
    final isTicking = seconds > 0;

    return Center(
      child: isTicking
          ? Text(
              'Resend link in ${seconds}s',
              style: SanctuaryTypography.bodySmall.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            )
          : TextButton.icon(
              onPressed: () {
                ref.read(authControllerProvider.notifier).startCooldownTimer();
                onResend?.call();
              },
              icon: Icon(Icons.refresh, size: 16, color: accent),
              label: Text(
                'Resend Verification Link',
                style: SanctuaryTypography.buttonPrimary.copyWith(color: accent, fontSize: 13.5),
              ),
            ),
    );
  }
}
