import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/vault_repository.dart';
import '../widgets/nominee_designation_modal.dart';

/// State representation for Statutory Vault & Governance (< 170 lines)
class StatutoryVaultState {
  final DataExportRecord? activeExport;
  final bool isExporting;
  final DataNominee nominee;
  final bool isSubmittingNominee;
  final List<BlockedProfile> blockedList;
  final String? successMessage;
  final String? errorMessage;

  const StatutoryVaultState({
    this.activeExport,
    this.isExporting = false,
    required this.nominee,
    this.isSubmittingNominee = false,
    required this.blockedList,
    this.successMessage,
    this.errorMessage,
  });

  String get exportStatus => activeExport?.status.name ?? 'none';
  String? get exportDownloadUrl => activeExport?.downloadUrl;
  int get blockedUsersCount => blockedList.length;

  StatutoryVaultState copyWith({
    DataExportRecord? activeExport,
    bool? isExporting,
    DataNominee? nominee,
    bool? isSubmittingNominee,
    List<BlockedProfile>? blockedList,
    String? successMessage,
    String? errorMessage,
  }) {
    return StatutoryVaultState(
      activeExport: activeExport ?? this.activeExport,
      isExporting: isExporting ?? this.isExporting,
      nominee: nominee ?? this.nominee,
      isSubmittingNominee: isSubmittingNominee ?? this.isSubmittingNominee,
      blockedList: blockedList ?? this.blockedList,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

/// Controller for DPDP Act 2023 Statutory Data Rights and Governance
class StatutoryVaultController extends StateNotifier<StatutoryVaultState> {
  final VaultRepository _repo;

  StatutoryVaultController(this._repo)
      : super(StatutoryVaultState(
          activeExport: _repo.getActiveExport(),
          nominee: _repo.getNominee(),
          blockedList: _repo.getBlockedList(),
        ));

  Future<void> requestDataExport([BuildContext? context]) async {
    state = state.copyWith(isExporting: true, errorMessage: null);
    try {
      final exportRecord = await _repo.requestDataExport();
      state = state.copyWith(
        activeExport: exportRecord,
        isExporting: false,
        successMessage: 'Signed archive generated! Download ready for 7 days.',
      );
    } catch (_) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Unable to request data archive. Try again later.',
      );
    }
  }

  void openNomineeDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NomineeDesignationModal(
        isDark: false,
        onSubmit: (name, contact, relationship) {
          designateNominee(
            name: name,
            contact: contact,
            relationship: relationship,
          );
        },
      ),
    );
  }

  Future<void> designateNominee({
    required String name,
    required String contact,
    required String relationship,
  }) async {
    state = state.copyWith(isSubmittingNominee: true, errorMessage: null);
    try {
      final updatedNominee = await _repo.designateNominee(
        name: name,
        contact: contact,
        relationship: relationship,
      );
      state = state.copyWith(
        nominee: updatedNominee,
        isSubmittingNominee: false,
        successMessage: 'Data Nominee appointed under DPDP Act Sec 14.',
      );
    } catch (_) {
      state = state.copyWith(
        isSubmittingNominee: false,
        errorMessage: 'Failed to designate nominee.',
      );
    }
  }

  Future<void> fileGrievance({
    required String category,
    required String evidenceText,
  }) async {
    try {
      await _repo.fileGrievanceDossier(
        category: category,
        evidenceText: evidenceText,
      );
      state = state.copyWith(
        successMessage: 'Grievance submitted. Statutory SLA: 24h ACK, 15d resolution.',
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to submit grievance dossier.');
    }
  }

  void unblockUser(String id) {
    _repo.unblockProfile(id);
    state = state.copyWith(
      blockedList: _repo.getBlockedList(),
      successMessage: 'User removed from blocked perimeter.',
    );
  }

  void clearBanner() {
    state = state.copyWith(successMessage: null, errorMessage: null);
  }
}

final statutoryVaultControllerProvider =
    StateNotifierProvider<StatutoryVaultController, StatutoryVaultState>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  return StatutoryVaultController(repo);
});
