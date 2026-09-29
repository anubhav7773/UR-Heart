import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/vault_models.dart';

/// Cards for IT Rules 2021 Grievance Dossier & Blocked Perimeter Management
class GrievanceComplianceSection extends StatelessWidget {
  final List<BlockedProfile> blockedList;
  final bool isDark;
  final VoidCallback onFileGrievance;
  final VoidCallback? onTrackGrievance;
  final VoidCallback onManageBlocked;

  const GrievanceComplianceSection({
    super.key,
    required this.blockedList,
    required this.isDark,
    required this.onFileGrievance,
    this.onTrackGrievance,
    required this.onManageBlocked,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grievance & Compliance (IT Rules 2021)',
            style: AppTypography.titleH2.copyWith(fontSize: 16, color: headlineColor),
          ),
          // Card 2.5: Designated Statutory Grievance Officer Transparency Card (IT Rules 2021 Rule 3(2))
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
                  children: [
                    Icon(Icons.gavel_rounded, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Statutory Grievance Officer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: headlineColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Designated Officer: Anubhav Singh (Asiverticals)\n'
                  'Registered Desk: District Court, Ayodhya, Uttar Pradesh - 224001\n'
                  'Statutory Email: asiverticals@gmail.com\n'
                  'Legal SLA: Formal acknowledgment within 24 hours, resolution within 15 days.',
                  style: AppTypography.bodySmall.copyWith(
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Card 3: Grievance Redressal Dossier
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
                Text(
                  'Grievance Redressal Dossier',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: headlineColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'File a priority statutory grievance under IT Rules 2021 Rule 3(2). SLA: 24-hr acknowledgment, 15-day resolution.',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onTrackGrievance != null)
                      TextButton.icon(
                        onPressed: onTrackGrievance,
                        icon: Icon(Icons.search, size: 16, color: accentColor),
                        label: Text(
                          'Track Status',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onFileGrievance,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor),
                        foregroundColor: accentColor,
                      ),
                      child: const Text('File Dossier ➔',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Card 4: Privacy & Blocked Perimeter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy & Blocked Perimeter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: headlineColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${blockedList.length} accounts blocked from viewing your sanctuary presence.',
                        style: AppTypography.bodySmall.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onManageBlocked,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? DarkSanctuaryTokens.secondaryPine
                        : LightSanctuaryTokens.primaryPine,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Manage (${blockedList.length}) ➔',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
