import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Restricted Superadmin KYC Sentinel Tile
/// STRICT SECURITY GATE: Compiles and renders EXCLUSIVELY for kshtriyaanubhav9120@gmail.com.
/// Returns SizedBox.shrink() (Zero trace in DOM) for all other users.
class SuperadminSentinelTile extends StatelessWidget {
  static const String authorizedSuperadminEmail = 'kshtriyaanubhav9120@gmail.com';
  static const String designatedAdminEmail = 'kshtriyaanubhav9120@gmail.com';

  final String? userEmail;
  final String? currentUserEmail;
  final bool isDark;
  final VoidCallback? onTap;

  const SuperadminSentinelTile({
    super.key,
    this.userEmail,
    this.currentUserEmail,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Zero-trust compile/runtime gate: Standard users get 0% UI trace
    final email = (currentUserEmail ?? userEmail ?? '').trim().toLowerCase();
    if (email != designatedAdminEmail) {
      return const SizedBox.shrink();
    }

    final goldColor = isDark
        ? DarkSanctuaryTokens.superadminGold
        : LightSanctuaryTokens.superadminGold;
    final goldBorder = isDark
        ? DarkSanctuaryTokens.superadminGoldBorder
        : LightSanctuaryTokens.superadminGoldBorder;
    final goldGlow = isDark
        ? DarkSanctuaryTokens.superadminGoldGlow
        : LightSanctuaryTokens.superadminGoldGlow;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: goldGlow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          final cb = onTap;
          if (cb != null) {
            cb();
          } else {
            Navigator.of(context).pushNamed('/admin/kyc-desk');
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.admin_panel_settings_rounded,
                  size: 24, color: goldColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '👑 Superadmin KYC Sentinel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: goldColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Review escalated video KYC reflections & Groq AI verification desk.',
                    style: AppTypography.bodySmall.copyWith(
                      color: headlineColor.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: goldColor),
          ],
        ),
      ),
    );
  }
}
