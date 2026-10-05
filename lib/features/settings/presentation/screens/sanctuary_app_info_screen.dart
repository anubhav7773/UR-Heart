import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';

/// Official App Info & Platform Overview Screen (`/appinfo`)
/// Displays sanctuary vision, core mindful pillars, and quick navigation.
class SanctuaryAppInfoScreen extends ConsumerWidget {
  static const String routeName = '/appinfo';

  const SanctuaryAppInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final muted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primary, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/sanctuary');
            }
          },
        ),
        title: Text(
          'Sanctuary Information',
          style: TextStyle(
            fontFamily: 'Serif',
            color: primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glowing Logo Hero
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E7E), Color(0xFF7952F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E7E).withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'UR-Heart',
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Safer · Kinder · Real',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: gold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A deliberate sanctuary built for genuine humans who value mindfulness, authentic presence, and sovereign personal privacy over shallow dopamine loops.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Feature Pillars
            _buildPillarTile(
              surface: surface,
              primary: primary,
              muted: muted,
              accentColor: pine,
              icon: Icons.spa_outlined,
              title: '10 Mindful Swipes / Day',
              desc: 'High-intent discovery capped at 10 daily intentional swipes for new seekers. Replenish +10 swipes anytime by taking a 10s mindful reflection ad, or unlock Sovereign passes for expanded presence.',
            ),
            const SizedBox(height: 12),

            _buildPillarTile(
              surface: surface,
              primary: primary,
              muted: muted,
              accentColor: const Color(0xFFFF2E7E),
              icon: Icons.psychology_outlined,
              title: '3-Engine Industry-Grade AI Suite',
              desc: 'Groq 3s biometric KYC & magnetic bio polish, OpenRouter Eva conversational companion, and Google Gemini 1-on-1 dialogue wingman.',
            ),
            const SizedBox(height: 12),

            _buildPillarTile(
              surface: surface,
              primary: primary,
              muted: muted,
              accentColor: const Color(0xFF7952F5),
              icon: Icons.bedtime_outlined,
              title: 'Night Sanctuary Slumber (10 PM - 6 AM)',
              desc: 'Put your phone face down to rest peacefully at night. Hardware sensors detect mindful slumber to reward bonus morning discovery swipes.',
            ),
            const SizedBox(height: 12),

            _buildPillarTile(
              surface: surface,
              primary: primary,
              muted: muted,
              accentColor: gold,
              icon: Icons.shield_outlined,
              title: 'Sovereign DPDP Vault & Sacred Bridge',
              desc: 'Bilateral mutual consent keys before contact reveal. Encrypted WhatsApp handles. Zero surveillance under India DPDP Act 2023.',
            ),
            const SizedBox(height: 12),

            _buildPillarTile(
              surface: surface,
              primary: primary,
              muted: muted,
              accentColor: const Color(0xFF4E9F76),
              icon: Icons.gavel_rounded,
              title: 'Statutory Grievance & Trust Desk',
              desc: 'Appointed Grievance Officer under India IT Rules 2021 & DPDP Act 2023. Fast-track human resolution within statutory SLAs at grievance@urheart.asiverticals.me.',
            ),
            const SizedBox(height: 28),

            // Primary Call to Action
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pine,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/sanctuary');
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Enter Sanctuary',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Statutory Legal Desk Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: gold,
                  side: BorderSide(color: gold.withValues(alpha: 0.6), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pushNamed('/vault'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Statutory Legal Vault & Grievance Desk',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer Version
            Text(
              'UR-Heart · Version 1.0.0 (Production Master)\nProtected by Statutory DPDP & Intermediary Rules',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarTile({
    required Color surface,
    required Color primary,
    required Color muted,
    required Color accentColor,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Serif',
                    color: primary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
