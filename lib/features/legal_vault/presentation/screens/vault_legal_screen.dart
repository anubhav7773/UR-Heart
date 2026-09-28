import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../domain/vault_models.dart';
import '../controllers/vault_controller.dart';
import '../widgets/blocked_perimeter_list.dart';
import '../widgets/data_rights_section.dart';
import '../widgets/grievance_compliance_section.dart';
import '../widgets/grievance_dossier_modal.dart';
import '../widgets/nominee_designation_modal.dart';
import '../widgets/statutory_badge_row.dart';

/// Screen 12: Statutory Vault & Data Rights
class VaultLegalScreen extends ConsumerWidget {
  static const String routeName = '/vault';

  const VaultLegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.activeTheme == SanctuaryTheme.dark;
    final state = ref.watch(vaultControllerProvider);
    final notifier = ref.read(vaultControllerProvider.notifier);

    final bgColor = isDark
        ? DarkSanctuaryTokens.background
        : LightSanctuaryTokens.background;
    final headlineColor = isDark
        ? DarkSanctuaryTokens.textHeadline
        : LightSanctuaryTokens.textHeadline;
    final mutedColor = isDark
        ? DarkSanctuaryTokens.textMuted
        : LightSanctuaryTokens.textMuted;

    ref.listen(vaultControllerProvider, (_, next) {
      if (next.successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage ?? ''),
            duration: const Duration(seconds: 2),
            backgroundColor: isDark
                ? DarkSanctuaryTokens.secondaryPine
                : LightSanctuaryTokens.primaryPine,
          ),
        );
        notifier.clearBanner();
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Statutory Vault',
          style: AppTypography.titleH1.copyWith(
            fontSize: 22,
            color: headlineColor,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? DarkSanctuaryTokens.secondaryPine
                  : LightSanctuaryTokens.chipBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 14,
                    color: isDark
                        ? DarkSanctuaryTokens.verifiedBadge
                        : LightSanctuaryTokens.verifiedBadge),
                const SizedBox(width: 4),
                Text(
                  'DPDP 2023',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: headlineColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatutoryBadgeRow(isDark: isDark),
              const SizedBox(height: 12),
              DataRightsSection(
                activeExport: state.activeExport,
                isExporting: state.isExporting,
                nominee: state.nominee,
                isDark: isDark,
                onRequestExport: () {
                  if (state.activeExport != null && state.activeExport?.status == ExportStatus.ready) {
                    notifier.downloadAndShareArchive();
                  } else {
                    notifier.requestDataExport();
                  }
                },
                onOpenNomineeModal: () => _openNomineeModal(context, isDark, notifier),
              ),
              const SizedBox(height: 16),
              GrievanceComplianceSection(
                blockedList: state.blockedList,
                isDark: isDark,
                onFileGrievance: () => _openGrievanceModal(context, isDark, notifier),
                onTrackGrievance: () => _openTrackGrievanceModal(context, isDark, notifier),
                onManageBlocked: () => _openBlockedList(context, isDark, state.blockedList, notifier),
              ),
              const SizedBox(height: 24),
              // Statutory Audit Footer
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'UR-HEART STATUTORY AUDIT ID: IND-DPDP-2023-VAULT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: mutedColor.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _openNomineeModal(BuildContext context, bool isDark, VaultController notifier) {
    showDialog<void>(
      context: context,
      builder: (_) => NomineeDesignationModal(
        isDark: isDark,
        onSubmit: (name, contact, rel) =>
            notifier.designateNominee(name: name, contact: contact, relationship: rel),
      ),
    );
  }

  void _openGrievanceModal(BuildContext context, bool isDark, VaultController notifier) {
    showDialog<void>(
      context: context,
      builder: (_) => GrievanceDossierModal(
        isDark: isDark,
        onSubmit: (cat, ev) => notifier.fileGrievance(category: cat, evidenceText: ev),
      ),
    );
  }

  void _openBlockedList(BuildContext context, bool isDark, List<BlockedProfile> list, VaultController notifier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlockedPerimeterList(
        blockedList: list,
        isDark: isDark,
        onUnblock: notifier.unblockUser,
      ),
    );
  }

  void _openTrackGrievanceModal(BuildContext context, bool isDark, VaultController notifier) {
    final controller = TextEditingController();
    Map<String, dynamic>? ticketData;
    bool isLoading = false;
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
          final border = isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder;
          final textHead = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
          final textSub = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
          final coral = isDark ? DarkSanctuaryTokens.primaryCoral : LightSanctuaryTokens.terracottaAccent;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Track Statutory Grievance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textHead),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSub, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'IT Rules 2021 Rule 3(2) statutory status and SLA countdown monitor.',
                  style: TextStyle(fontSize: 12, color: textSub),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: TextStyle(fontSize: 13, color: textHead),
                        decoration: InputDecoration(
                          hintText: 'Enter Reference ID (e.g. GRV-...)',
                          hintStyle: TextStyle(fontSize: 12, color: textSub),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: coral,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final refId = controller.text.trim();
                              if (refId.isEmpty) return;
                              setModalState(() {
                                isLoading = true;
                                error = null;
                              });
                              final res = await notifier.trackGrievance(refId);
                              setModalState(() {
                                isLoading = false;
                                if (res != null) {
                                  ticketData = res;
                                } else {
                                  error = 'Ticket not found or query error.';
                                }
                              });
                            },
                      child: isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Track ➔', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                if (ticketData != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16211C) : const Color(0xFFF6F8F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ticketData!['reference_id']?.toString() ?? 'TICKET',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: coral),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: coral.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (ticketData!['status']?.toString() ?? 'PENDING').toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: coral),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${ticketData!['violation_category'] ?? "General"}',
                          style: TextStyle(fontSize: 12, color: textHead),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SLA Resolution Target: ${ticketData!['sla_resolution_target'] ?? "15 Days"}',
                          style: TextStyle(fontSize: 12, color: textSub),
                        ),
                        if (ticketData!['officer_notes'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Grievance Officer: ${ticketData!['officer_notes']}',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: textHead),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
