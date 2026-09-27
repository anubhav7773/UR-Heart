import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Search input bar with filter trigger for Chats Hub (Screen 8)
class ChatsSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final bool isDark;

  const ChatsSearchBar({
    super.key,
    required this.onChanged,
    this.onFilterTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.inputBackground
        : LightSanctuaryTokens.inputBackground;
    final borderColor = isDark
        ? DarkSanctuaryTokens.inputBorder
        : LightSanctuaryTokens.inputBorder;
    final textColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final hintColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final iconColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.primaryPine;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: hintColor, size: 20.0),
          const SizedBox(width: 10.0),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: AppTypography.bodyStandard.copyWith(color: textColor, fontSize: 14.0),
              decoration: InputDecoration(
                hintText: 'Search heartfelt conversations...',
                hintStyle: AppTypography.bodySmall.copyWith(color: hintColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(Icons.tune_rounded, color: iconColor, size: 20.0),
            ),
          ),
        ],
      ),
    );
  }
}
