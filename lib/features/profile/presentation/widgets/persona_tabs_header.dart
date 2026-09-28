import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../navigation/presentation/screens/sanctuary_navigation_shell.dart';

/// Top horizontal tab switcher between Persona, Growth PRO, and Vault & Legal
class PersonaTabsHeader extends ConsumerWidget {
  final int activeIndex;
  final bool isDark;

  const PersonaTabsHeader({
    super.key,
    required this.activeIndex,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBg = isDark
        ? DarkSanctuaryTokens.secondaryPine
        : LightSanctuaryTokens.primaryPine;
    final inactiveBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.chipBackground;
    const activeText = Colors.white;
    final inactiveText = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab(
            title: '1. My Persona',
            isActive: activeIndex == 0,
            activeBg: activeBg,
            inactiveBg: inactiveBg,
            activeText: activeText,
            inactiveText: inactiveText,
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 4;
            },
          ),
          const SizedBox(width: 8),
          _buildTab(
            title: '2. Growth PRO',
            isActive: activeIndex == 1,
            activeBg: activeBg,
            inactiveBg: inactiveBg,
            activeText: activeText,
            inactiveText: inactiveText,
            onTap: () {
              ref.read(navigationIndexProvider.notifier).state = 3;
            },
          ),
          const SizedBox(width: 8),
          _buildTab(
            title: '3. Vault & Legal',
            isActive: activeIndex == 2,
            activeBg: activeBg,
            inactiveBg: inactiveBg,
            activeText: activeText,
            inactiveText: inactiveText,
            onTap: () {
              Navigator.of(context).pushNamed('/vault');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required bool isActive,
    required Color activeBg,
    required Color inactiveBg,
    required Color activeText,
    required Color inactiveText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}
