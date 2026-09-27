import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/alerts_toggle_group.dart';
import '../widgets/discovery_privacy_card.dart';
import '../widgets/irrevocable_erasure_modal.dart';
import '../widgets/superadmin_sentinel_tile.dart';

/// Screen 13: Sanctuary Preferences & Governance
class SanctuarySettingsScreen extends ConsumerWidget {
  static const String routeName = '/settings';

  const SanctuarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;
    final state = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final verifiedBadge = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    ref.listen(settingsControllerProvider, (_, next) {
      if (next.successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? ''),
            duration: const Duration(seconds: 2),
            backgroundColor: isDark
                ? DarkSanctuaryTokens.secondaryPine
                : LightSanctuaryTokens.primaryPine,
          ),
        );
        notifier.clearBanner();
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Sanctuary Preferences',
          style: AppTypography.titleH1.copyWith(
            fontSize: 20,
            color: headlineColor,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: verifiedBadge.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: verifiedBadge.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: verifiedBadge),
                const SizedBox(width: 4),
                Text(
                  'E2E Shielded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: verifiedBadge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlertsToggleGroup(
                settings: state.settings,
                isDark: isDark,
                onMasterChanged: notifier.toggleMasterResonance,
                onDiscreetChanged: notifier.toggleDiscreetMode,
                onNightSlumberChanged: notifier.toggleNightSlumber,
              ),
              DiscoveryPrivacyCard(
                settings: state.settings,
                isDark: isDark,
                isRotatingKey: state.isRotatingKey,
                onIncognitoChanged: notifier.toggleIncognito,
                onRotateKey: notifier.rotateKey,
              ),
              // Superadmin Sentinel Tile: Only renders for kshtriyaanubhav9120@gmail.com
              SuperadminSentinelTile(
                userEmail: state.settings.userEmail,
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/kyc-desk');
                },
              ),
              SovereignControlSection(
                isDark: isDark,
                isIncinerating: state.isIncinerating,
                onLogOut: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/consent',
                    (route) => false,
                  );
                },
                onConfirmErasure: () async {
                  final ok = await notifier.incinerateAccount();
                  if (ok && context.mounted) {
                    await ref.read(themeProvider.notifier).resetThemeLock();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/consent',
                        (route) => false,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
