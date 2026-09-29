import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Statutory Legal & Data Privacy Portals card on the Consent Screen.
/// Enables any user (even without signing in) to open Privacy Policy, Terms, 
/// and Account/Data Deletion in their external browser with 1 tap.
class StatutoryLinksCard extends StatelessWidget {
  final bool isDark;

  const StatutoryLinksCard({super.key, required this.isDark});

  Future<void> _openExternalUrl(BuildContext context, String urlString, String label) async {
    final uri = Uri.parse(urlString);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $label in browser ($urlString).'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $label: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? DarkSanctuaryTokens.surfaceCard
        : LightSanctuaryTokens.surfaceCard;
    final cardBorder = isDark
        ? DarkSanctuaryTokens.surfaceCardBorder
        : LightSanctuaryTokens.surfaceCardBorder;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;
    final goldAccent = isDark
        ? DarkSanctuaryTokens.goldAccent
        : LightSanctuaryTokens.goldAccent;
    final pine = isDark
        ? DarkSanctuaryTokens.sanctuaryPine
        : LightSanctuaryTokens.sanctuaryPine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: goldAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: goldAccent.withOpacity(0.4)),
                ),
                child: Icon(Icons.shield_outlined, color: goldAccent, size: 20.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUTORY LEGAL PORTALS',
                      style: TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: goldAccent,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Open official legal documents in browser',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Portal 1: Privacy Policy
          _buildPortalTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            iconColor: pine,
            title: 'Privacy Policy',
            subtitle: 'DPDP Act 2023 & IT Rules 2021 compliance',
            url: ApiEndpoints.privacyPolicyUrl,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            goldAccent: goldAccent,
          ),
          const SizedBox(height: 8.0),

          // Portal 2: Terms of Service & EULA
          _buildPortalTile(
            context: context,
            icon: Icons.gavel_rounded,
            iconColor: goldAccent,
            title: 'Terms of Service & EULA',
            subtitle: 'Section 79 IT Act safe harbor & user conduct',
            url: ApiEndpoints.termsOfServiceUrl,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            goldAccent: goldAccent,
          ),
          const SizedBox(height: 8.0),

          // Portal 3: Account & Data Deletion Portal
          _buildPortalTile(
            context: context,
            icon: Icons.delete_forever_outlined,
            iconColor: const Color(0xFFE05353),
            title: 'Account & Data Deletion',
            subtitle: 'Google Play & DPDP erasure portal without app login',
            url: ApiEndpoints.deleteAccountUrl,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            goldAccent: goldAccent,
          ),
          const SizedBox(height: 8.0),

          // Portal 4: Official Parent Web Sanctuary
          _buildPortalTile(
            context: context,
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF4E9F76),
            title: 'Official Web Sanctuary',
            subtitle: 'urheart.asiverticals.me',
            url: ApiEndpoints.webSanctuaryUrl,
            headlineColor: headlineColor,
            mutedColor: mutedColor,
            goldAccent: goldAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildPortalTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String url,
    required Color headlineColor,
    required Color mutedColor,
    required Color goldAccent,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => _openExternalUrl(context, url, title),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white.withOpacity(isDark ? 0.08 : 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20.0),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.0,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(
                Icons.open_in_new_rounded,
                size: 16.0,
                color: goldAccent.withOpacity(0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
