import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// App bar for 1:1 Encrypted Dialogue (Screen 9) with WA Key badge and online indicator
class DialogueAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String recipientName;
  final int recipientAge;
  final bool isOnline;
  final bool hasWaKey;
  final bool isDark;
  final VoidCallback onBack;

  const DialogueAppBar({
    super.key,
    required this.recipientName,
    required this.recipientAge,
    required this.isOnline,
    required this.hasWaKey,
    required this.isDark,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final titleColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final waKeyColor = isDark
        ? DarkSanctuaryTokens.badgeWaKey
        : LightSanctuaryTokens.badgeWaKey;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: titleColor, size: 18.0),
                onPressed: onBack,
              ),
              _buildAvatar(),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$recipientName, $recipientAge',
                      style: AppTypography.titleH2.copyWith(color: titleColor, fontSize: 16.0),
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      children: [
                        Container(
                          width: 7.0,
                          height: 7.0,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? (isDark ? DarkSanctuaryTokens.badgeOnline : LightSanctuaryTokens.badgeOnline)
                                : mutedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        Text(
                          isOnline ? 'Online now' : 'Mindful presence',
                          style: AppTypography.caption.copyWith(color: mutedColor, fontSize: 11.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasWaKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: waKeyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: waKeyColor.withOpacity(0.4), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 12.0, color: waKeyColor),
                      const SizedBox(width: 4.0),
                      Text(
                        'WA Key ✓',
                        style: TextStyle(
                          color: waKeyColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 6.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 20.0,
          backgroundColor: isDark
              ? DarkSanctuaryTokens.surfaceCard
              : LightSanctuaryTokens.chipBackground,
          child: Text(
            recipientName.isNotEmpty ? recipientName[0] : 'U',
            style: AppTypography.titleH2.copyWith(
              color: isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.primaryPine,
              fontSize: 15.0,
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                color: isDark ? DarkSanctuaryTokens.badgeOnline : LightSanctuaryTokens.badgeOnline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
