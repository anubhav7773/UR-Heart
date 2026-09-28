import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';

/// Interactive Sanctuary Atmosphere Card to switch themes app-wide from Settings
class AtmosphereThemeCard extends StatelessWidget {
  final SanctuaryThemeMode activeMode;
  final bool isDark;
  final ValueChanged<SanctuaryThemeMode> onThemeChanged;

  const AtmosphereThemeCard({
    super.key,
    required this.activeMode,
    required this.isDark,
    required this.onThemeChanged,
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
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atmosphere & Sanctuary Theme',
                      style: AppTypography.titleH2.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Switch between serene Light and contemplative Dark modes across the entire app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ThemeOptionTile(
                  title: 'Daybreak Light',
                  subtitle: 'Soft warmth & clarity',
                  icon: Icons.wb_sunny_rounded,
                  isSelected: activeMode == SanctuaryThemeMode.light,
                  isDark: isDark,
                  activeColor: LightSanctuaryTokens.primaryPine,
                  onTap: () => onThemeChanged(SanctuaryThemeMode.light),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeOptionTile(
                  title: 'Midnight Dark',
                  subtitle: 'Earthy pine & quietude',
                  icon: Icons.nightlight_round,
                  isSelected: activeMode == SanctuaryThemeMode.dark,
                  isDark: isDark,
                  activeColor: DarkSanctuaryTokens.secondaryPine,
                  onTap: () => onThemeChanged(SanctuaryThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final Color activeColor;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileBg = isSelected
        ? activeColor.withValues(alpha: 0.14)
        : (isDark
            ? DarkSanctuaryTokens.inputBackground
            : LightSanctuaryTokens.chipBackground);
    final borderColor = isSelected
        ? activeColor
        : (isDark
            ? DarkSanctuaryTokens.surfaceCardBorder
            : LightSanctuaryTokens.surfaceCardBorder);
    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final muted = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? activeColor : muted,
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: activeColor,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
