import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/vault_repository.dart';

class VaultState {
  final DataExportRecord? activeExport;
  final bool isExporting;
  final DataNominee nominee;
  final bool isSubmittingNominee;
  final List<BlockedProfile> blockedList;
  final String? successMessage;
  final String? errorMessage;

  const VaultState({
    this.activeExport,
    this.isExporting = false,
    required this.nominee,
    this.isSubmittingNominee = false,
    required this.blockedList,
    this.successMessage,
    this.errorMessage,
  });

  VaultState copyWith({
    DataExportRecord? activeExport,
    bool? isExporting,
    DataNominee? nominee,
    bool? isSubmittingNominee,
    List<BlockedProfile>? blockedList,
    String? successMessage,
    String? errorMessage,
  }) {
    return VaultState(
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

class VaultController extends StateNotifier<VaultState> {
  final VaultRepository _repo;

  VaultController(this._repo)
      : super(VaultState(
          activeExport: _repo.getActiveExport(),
          nominee: _repo.getNominee(),
          blockedList: _repo.getBlockedList(),
        ));

  Future<void> requestDataExport() async {
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

final vaultControllerProvider =
    StateNotifierProvider<VaultController, VaultState>((ref) {
  final repo = ref.watch(vaultRepositoryProvider);
  return VaultController(repo);
});
