import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Row of 3 statutory security badge chips at the top of Screen 12
class StatutoryBadgeRow extends StatelessWidget {
  final bool isDark;

  const StatutoryBadgeRow({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final chipBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final chipBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final badgeColor = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;
    final textColor = isDark
        ? DarkSanctuaryTokens.textBody
        : LightSanctuaryTokens.textBody;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(
            icon: Icons.lock_outline_rounded,
            title: 'E2E Encrypted (Curve25519)',
            chipBg: chipBg,
            chipBorder: chipBorder,
            badgeColor: badgeColor,
            textColor: textColor,
          ),
          const SizedBox(width: 8),
          _buildChip(
            icon: Icons.shield_outlined,
            title: 'Zero Logs (Statutory Vault)',
            chipBg: chipBg,
            chipBorder: chipBorder,
            badgeColor: badgeColor,
            textColor: textColor,
          ),
          const SizedBox(width: 8),
          _buildChip(
            icon: Icons.gavel_rounded,
            title: 'DPDP Act 2023 Compliant',
            chipBg: chipBg,
            chipBorder: chipBorder,
            badgeColor: badgeColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String title,
    required Color chipBg,
    required Color chipBorder,
    required Color badgeColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
