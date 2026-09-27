import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../light_sanctuary_tokens.dart';
import '../dark_sanctuary_tokens.dart';
import '../sanctuary_typography.dart';
import '../theme_controller.dart';

class PermanentThemeLockDialog extends ConsumerWidget {
  final SanctuaryThemeMode? targetTheme;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const PermanentThemeLockDialog({
    super.key,
    this.targetTheme,
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final activeMode = targetTheme ?? themeState.mode;
    final isDark = activeMode == SanctuaryThemeMode.dark;

    final bgColor = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final textColor = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subColor = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final accentColor = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.sanctuaryPine;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Permanent Visual Sanctuary',
        textAlign: TextAlign.center,
        style: SanctuaryTypography.titleH2.copyWith(color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UR-Heart enforces an unhurried, permanent visual mode. Once locked, this theme cannot be toggled again on this installation.',
            textAlign: TextAlign.center,
            style: SanctuaryTypography.bodyStandard.copyWith(color: subColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Light Mode'),
                selected: themeState.mode == SanctuaryThemeMode.light,
                onSelected: (_) => ref
                    .read(themeControllerProvider.notifier)
                    .switchDraftMode(SanctuaryThemeMode.light),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Dark Mode'),
                selected: themeState.mode == SanctuaryThemeMode.dark,
                onSelected: (_) => ref
                    .read(themeControllerProvider.notifier)
                    .switchDraftMode(SanctuaryThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () {
            if (onCancel != null) {
              onCancel?.call();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text('Keep Current', style: TextStyle(color: subColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            if (onConfirm != null) {
              onConfirm?.call();
            } else {
              await ref.read(themeControllerProvider.notifier).lockThemePermanently();
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          child: const Text('Confirm & Lock', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
