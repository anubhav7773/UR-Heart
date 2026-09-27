import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../controllers/profile_setup_controller.dart';

class SacredBridgeSelector extends ConsumerStatefulWidget {
  const SacredBridgeSelector({super.key});

  @override
  ConsumerState<SacredBridgeSelector> createState() => _SacredBridgeSelectorState();
}

class _SacredBridgeSelectorState extends ConsumerState<SacredBridgeSelector> {
  String _selectedPlatform = 'whatsapp';
  final TextEditingController _handleController = TextEditingController();

  final Map<String, String> _platformLabels = {
    'whatsapp': 'WhatsApp (Phone Number)',
    'instagram': 'Instagram (@handle)',
    'snapchat': 'Snapchat (Username)',
    'telegram': 'Telegram (@username)',
    'signal': 'Signal (Username / ID)',
  };

  final Map<String, String> _placeholders = {
    'whatsapp': '+91 98765 43210',
    'instagram': '@mindful_presence',
    'snapchat': 'snap_presence',
    'telegram': '@t_sanctuary',
    'signal': 'signal.01',
  };

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;

    final primaryText = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final subText = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;
    final surface = isDark ? DarkSanctuaryTokens.surfaceMuted : LightSanctuaryTokens.surfaceMuted;
    final accent = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.accentTerracotta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_clock_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              'Sacred Contact Bridge',
              style: TextStyle(fontWeight: FontWeight.w600, color: primaryText, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Encrypted locally. Unmasked only after reciprocal 3/3 reveal ritual.',
          style: TextStyle(fontSize: 12, color: subText),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPlatform,
              isExpanded: true,
              dropdownColor: isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface,
              icon: Icon(Icons.arrow_drop_down, color: primaryText),
              items: _platformLabels.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value, style: TextStyle(color: primaryText, fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedPlatform = val;
                  _handleController.clear();
                });
                _notifyParent();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _handleController,
          style: TextStyle(color: primaryText, fontSize: 14),
          keyboardType: _selectedPlatform == 'whatsapp' ? TextInputType.phone : TextInputType.text,
          onChanged: (_) => _notifyParent(),
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            hintText: _placeholders[_selectedPlatform],
            hintStyle: TextStyle(color: subText.withValues(alpha: 0.6), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _notifyParent() {
    ref.read(profileSetupControllerProvider.notifier).updateContactBridge(
      platform: _selectedPlatform,
      handle: _handleController.text.trim(),
    );
  }
}
