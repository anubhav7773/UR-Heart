import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Segmented dual tab switcher between 'Liked You' and 'Mutual Connections'
class ResonanceSegmentedTab extends StatelessWidget {
  final int activeTab;
  final int likesCount;
  final int mutualCount;
  final bool isDark;
  final ValueChanged<int> onTabSelected;

  const ResonanceSegmentedTab({
    super.key,
    required this.activeTab,
    required this.likesCount,
    required this.mutualCount,
    required this.isDark,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;

    final activeText = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    final inactiveText = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    final containerBg = isDark
        ? const Color(0xFF131F19)
        : const Color(0xFFEBE6DC);

    return Container(
      height: 46.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(23.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: activeTab == 0 ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(19.0),
                  boxShadow: activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 6.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Liked You ($likesCount)',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: activeTab == 0 ? activeText : inactiveText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: activeTab == 1 ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(19.0),
                  boxShadow: activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 6.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Mutual ($mutualCount)',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: activeTab == 1 ? activeText : inactiveText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
