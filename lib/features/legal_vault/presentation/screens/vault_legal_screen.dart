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
                onRequestExport: notifier.requestDataExport,
                onOpenNomineeModal: () => _openNomineeModal(context, isDark, notifier),
              ),
              const SizedBox(height: 16),
              GrievanceComplianceSection(
                blockedList: state.blockedList,
                isDark: isDark,
                onFileGrievance: () => _openGrievanceModal(context, isDark, notifier),
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
}
