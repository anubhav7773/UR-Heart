import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class FeedFloatingActionBar extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onResonate;
  final VoidCallback onLike;
  final bool isDark;

  const FeedFloatingActionBar({
    super.key,
    required this.onPass,
    required this.onResonate,
    required this.onLike,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? DarkSanctuaryTokens.surface
        : LightSanctuaryTokens.surface;
    final secondaryText = isDark
        ? DarkSanctuaryTokens.secondaryText
        : LightSanctuaryTokens.secondaryText;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;
    final terracotta = isDark
        ? DarkSanctuaryTokens.accentTerracotta
        : LightSanctuaryTokens.accentTerracotta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass Button (✕)
          _buildActionButton(
            size: 54.0,
            bgColor: surface,
            borderColor: secondaryText.withValues(alpha: 0.25),
            icon: Icons.close_rounded,
            iconColor: terracotta,
            iconSize: 26.0,
            onTap: onPass,
          ),
          const SizedBox(width: 14.0),
          // Direct Resonate Button (✉)
          Expanded(
            child: SizedBox(
              height: 52.0,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pine,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.0)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18.0),
                label: const Text(
                  'Direct Resonate ✉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                  ),
                ),
                onPressed: onResonate,
              ),
            ),
          ),
          const SizedBox(width: 14.0),
          // Like Button (♡)
          _buildActionButton(
            size: 54.0,
            bgColor: surface,
            borderColor: pine.withValues(alpha: 0.35),
            icon: Icons.favorite_rounded,
            iconColor: pine,
            iconSize: 26.0,
            onTap: onLike,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required double size,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}
