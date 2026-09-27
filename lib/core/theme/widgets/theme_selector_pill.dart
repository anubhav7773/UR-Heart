import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../light_sanctuary_tokens.dart';
import '../dark_sanctuary_tokens.dart';
import '../sanctuary_typography.dart';
import '../theme_controller.dart';
import 'permanent_theme_lock_dialog.dart';

class ThemeSelectorPill extends ConsumerWidget {
  const ThemeSelectorPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    if (themeState.isLocked) {
      final bg = isDark ? DarkSanctuaryTokens.secondaryPine : LightSanctuaryTokens.chipBackground;
      final textCol = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 14, color: isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine),
            const SizedBox(width: 6),
            Text(isDark ? 'Dark Sanctuary' : 'Light Sanctuary', style: SanctuaryTypography.caption.copyWith(color: textCol, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final pillBg = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final pillBorder = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final textCol = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final targetTheme = isDark ? SanctuaryThemeMode.light : SanctuaryThemeMode.dark;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => PermanentThemeLockDialog(
            targetTheme: targetTheme,
            onConfirm: () {
              ref.read(themeControllerProvider.notifier).switchAndLockTheme(targetTheme);
              Navigator.of(dialogCtx).pop();
            },
            onCancel: () => Navigator.of(dialogCtx).pop(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: pillBorder, width: 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 14, color: isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine),
            const SizedBox(width: 6),
            Text(isDark ? 'Dark Mode' : 'Light Mode', style: SanctuaryTypography.caption.copyWith(color: textCol, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText),
          ],
        ),
      ),
    );
  }
}
