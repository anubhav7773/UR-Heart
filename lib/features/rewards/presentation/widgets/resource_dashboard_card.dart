import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// 3-Metric dashboard card displaying active sanctuary balance
class ResourceDashboardCard extends StatelessWidget {
  final int swipesRemaining;
  final int directLettersCount;
  final int whatsappProgress;
  final bool isDark;

  const ResourceDashboardCard({
    super.key,
    required this.swipesRemaining,
    required this.directLettersCount,
    required this.whatsappProgress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.style_outlined,
                value: '$swipesRemaining left',
                title: 'Swipes Remaining',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.mark_email_unread_outlined,
                value: '$directLettersCount remaining',
                title: 'Direct Letters',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.vpn_key_outlined,
                value: '$whatsappProgress of 3 completed',
                title: 'WhatsApp Key Progress',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String title,
  }) {
    final bgColor = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final borderColor = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.buttonPrimary.copyWith(
              color: headlineColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: mutedColor,
              fontSize: 10.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
