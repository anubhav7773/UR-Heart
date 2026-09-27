import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Segmented tab switcher between 'Create Sanctuary' and 'Sign In'
class AuthTabSwitcher extends StatelessWidget {
  final bool isSignIn;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const AuthTabSwitcher({
    super.key,
    required this.isSignIn,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final textActive = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final textInactive = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      height: 44.0,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F19) : const Color(0xFFEBE6DC),
        borderRadius: BorderRadius.circular(22.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                decoration: BoxDecoration(
                  color: !isSignIn ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Center(
                  child: Text(
                    'Create Sanctuary',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: !isSignIn ? textActive : textInactive,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                decoration: BoxDecoration(
                  color: isSignIn ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Center(
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: isSignIn ? textActive : textInactive,
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
