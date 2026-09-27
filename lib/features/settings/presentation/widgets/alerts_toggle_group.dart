import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/settings_models.dart';

/// Group of switch toggles for push alerts, discreet previews, and night slumber
class AlertsToggleGroup extends StatelessWidget {
  final SanctuarySettings? settings;
  final bool? discreetMode;
  final bool? nightSlumber;
  final bool? masterPush;
  final bool isDark;
  final ValueChanged<bool>? onMasterChanged;
  final ValueChanged<bool>? onDiscreetChanged;
  final ValueChanged<bool>? onNightSlumberChanged;
  final ValueChanged<bool>? onToggleDiscreet;
  final ValueChanged<bool>? onToggleSlumber;
  final ValueChanged<bool>? onTogglePush;

  const AlertsToggleGroup({
    super.key,
    this.settings,
    this.discreetMode,
    this.nightSlumber,
    this.masterPush,
    required this.isDark,
    this.onMasterChanged,
    this.onDiscreetChanged,
    this.onNightSlumberChanged,
    this.onToggleDiscreet,
    this.onToggleSlumber,
    this.onTogglePush,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final activeColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alerts & Ambient Silence',
            style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
          ),
          const SizedBox(height: 12),
          // 1. Master Resonance
          _buildToggle(
            title: 'Master Resonance Alerts',
            subtitle: 'Enables or silences all incoming heartbeat pushes.',
            value: masterPush ?? settings?.masterResonance ?? true,
            activeColor: activeColor,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            onChanged: (val) {
              final cb = onTogglePush ?? onMasterChanged;
              if (cb != null) cb(val);
            },
          ),
          const Divider(height: 20),
          // 2. Discreet Mode
          _buildToggle(
            title: 'Discreet Sanctuary Mode',
            subtitle: 'Masks candidate names and preview text in lock-screen notices.',
            value: discreetMode ?? settings?.discreetMode ?? false,
            activeColor: activeColor,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            onChanged: (val) {
              final cb = onToggleDiscreet ?? onDiscreetChanged;
              if (cb != null) cb(val);
            },
          ),
          const Divider(height: 20),
          // 3. Night Sanctuary Slumber
          _buildToggle(
            title: 'Night Sanctuary Slumber',
            subtitle: 'Silences all notifications automatically from 11 PM to 7 AM.',
            value: nightSlumber ?? settings?.nightSanctuarySlumber ?? true,
            activeColor: activeColor,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            onChanged: (val) {
              final cb = onToggleSlumber ?? onNightSlumberChanged;
              if (cb != null) cb(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required Color headlineColor,
    required Color mutedColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: headlineColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
