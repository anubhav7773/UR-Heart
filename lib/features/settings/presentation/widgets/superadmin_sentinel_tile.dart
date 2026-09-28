import 'package:flutter/material.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';

class SuperadminSentinelTile extends StatelessWidget {
  final String userRole; // Resolved securely from server-side database claims
  final bool isDark;
  final VoidCallback? onTap;

  const SuperadminSentinelTile({
    super.key,
    required this.userRole,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Zero client-side hardcoded email strings. 
    // Renders solely upon cryptographically validated server-side role claim.
    if (userRole.toLowerCase().trim() != 'superadmin') {
      return const SizedBox.shrink();
    }

    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: gold, size: 22),
              const SizedBox(width: 8),
              Text(
                'SOVEREIGN SENTINEL DESK',
                style: TextStyle(
                  fontFamily: 'Serif',
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Authorized access granted. Inspect escalated live verification reflections.',
            style: TextStyle(fontSize: 12, color: sub, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.security, color: Colors.black, size: 16),
              label: const Text(
                'Open KYC Escalation Desk ➔',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () {
                if (onTap != null) {
                  onTap!();
                } else {
                  Navigator.of(context).pushNamed('/admin/kyc-desk');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
