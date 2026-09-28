import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/vault_models.dart';

/// Cards displaying statutory data rights under DPDP Act 2023 Sec 11 & Sec 14
class DataRightsSection extends StatelessWidget {
  final DataExportRecord? activeExport;
  final bool isExporting;
  final DataNominee nominee;
  final bool isDark;
  final VoidCallback onRequestExport;
  final VoidCallback onOpenNomineeModal;

  const DataRightsSection({
    super.key,
    required this.activeExport,
    required this.isExporting,
    required this.nominee,
    required this.isDark,
    required this.onRequestExport,
    required this.onOpenNomineeModal,
  });

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
    final accentColor = isDark
        ? DarkSanctuaryTokens.primaryCoral
        : LightSanctuaryTokens.terracottaAccent;
    final verifiedBadge = isDark
        ? DarkSanctuaryTokens.verifiedBadge
        : LightSanctuaryTokens.verifiedBadge;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statutory Data Rights (DPDP Act 2023)',
            style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
          ),
          const SizedBox(height: 12),
          // Card 1: Download My Data (Sec 11)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Download My Data (DPDP Act Sec 11)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                      ),
                    ),
                    Icon(Icons.download_for_offline_outlined,
                        size: 20, color: verifiedBadge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Download a cryptographically signed JSON archive of all your moments, logs, and reflections.',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 12),
                if (activeExport != null && activeExport?.status == ExportStatus.ready) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: verifiedBadge.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: verifiedBadge.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: verifiedBadge),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Archive Ready · ${activeExport?.expiresText}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: verifiedBadge),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: isExporting ? null : onRequestExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            activeExport != null && activeExport?.status == ExportStatus.ready
                                ? 'Download / Share Archive (.JSON) ➔'
                                : 'Request Export ➔',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Card 2: Designate Data Nominee (Sec 14)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Designate Data Nominee (DPDP Act Sec 14)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                      ),
                    ),
                    Icon(Icons.person_add_alt_1_outlined,
                        size: 20, color: verifiedBadge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Appoint a trusted representative to manage your sanctuary presence in case of unforeseen events.',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 12),
                if (nominee.isDesignated) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DarkSanctuaryTokens.inputBackground
                          : LightSanctuaryTokens.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Nominee: ${nominee.name} (${nominee.relationship}) · ${nominee.contact}',
                      style: TextStyle(fontSize: 12, color: headlineColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: onOpenNomineeModal,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      foregroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      nominee.isDesignated ? 'Update Nominee ➔' : 'Designate ➔',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
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
