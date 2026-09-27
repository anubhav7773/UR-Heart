import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/profile_setup_controller.dart';

class BioEditorWithAi extends ConsumerStatefulWidget {
  const BioEditorWithAi({super.key});

  @override
  ConsumerState<BioEditorWithAi> createState() => _BioEditorWithAiState();
}

class _BioEditorWithAiState extends ConsumerState<BioEditorWithAi> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final setupState = ref.watch(profileSetupControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final surface = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mindful Bio', style: TextStyle(fontWeight: FontWeight.w600, color: primaryText)),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: setupState.isBioPolishing
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.auto_awesome, color: gold, size: 14),
              label: Text(
                'Mindful Polish ✨',
                style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: setupState.isBioPolishing
                  ? null
                  : () async {
                      if (_controller.text.trim().isEmpty) return;
                      final polished = await ref
                          .read(profileSetupControllerProvider.notifier)
                          .polishBioWithGroq(_controller.text.trim());
                      if (polished != null && mounted) {
                        setState(() => _controller.text = polished);
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: 4,
          maxLength: 500,
          style: TextStyle(color: primaryText, fontSize: 14, height: 1.4),
          onChanged: (text) => ref.read(profileSetupControllerProvider.notifier).updateBio(text.trim()),
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            hintText: 'Share a quiet glimpse into your rituals, passions, and presence...',
            hintStyle: TextStyle(color: subText.withValues(alpha: 0.6), fontSize: 13),
            counterStyle: TextStyle(color: subText, fontSize: 11),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
