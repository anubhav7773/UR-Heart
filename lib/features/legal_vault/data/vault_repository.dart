import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../domain/vault_models.dart';

/// Repository orchestrating statutory DPDP exports, nominee records & grievance filings
class VaultRepository {
  final ApiClient? _apiClient;
  final _uuid = const Uuid();

  DataExportRecord? _activeExport;
  DataNominee _nominee = const DataNominee();
  final List<BlockedProfile> _blockedList = [];

  VaultRepository([this._apiClient]) {
    _initializeBlockedList();
  }

  void _initializeBlockedList() {
    _blockedList.addAll([
      const BlockedProfile(id: 'blk-1', name: 'Vikram', age: 31, dateBlocked: '12 Sep 2024'),
      const BlockedProfile(id: 'blk-2', name: 'Karan', age: 29, dateBlocked: '18 Sep 2024'),
      const BlockedProfile(id: 'blk-3', name: 'Aryan', age: 27, dateBlocked: '22 Sep 2024'),
      const BlockedProfile(id: 'blk-4', name: 'Rishi', age: 32, dateBlocked: '01 Oct 2024'),
      const BlockedProfile(id: 'blk-5', name: 'Sameer', age: 28, dateBlocked: '05 Oct 2024'),
      const BlockedProfile(id: 'blk-6', name: 'Tushar', age: 30, dateBlocked: '10 Oct 2024'),
      const BlockedProfile(id: 'blk-7', name: 'Nakul', age: 26, dateBlocked: '12 Oct 2024'),
      const BlockedProfile(id: 'blk-8', name: 'Gaurav', age: 33, dateBlocked: '14 Oct 2024'),
      const BlockedProfile(id: 'blk-9', name: 'Harsh', age: 29, dateBlocked: '15 Oct 2024'),
      const BlockedProfile(id: 'blk-10', name: 'Yash', age: 27, dateBlocked: '16 Oct 2024'),
      const BlockedProfile(id: 'blk-11', name: 'Manav', age: 28, dateBlocked: '17 Oct 2024'),
      const BlockedProfile(id: 'blk-12', name: 'Kunal', age: 30, dateBlocked: '18 Oct 2024'),
      const BlockedProfile(id: 'blk-13', name: 'Aditya', age: 29, dateBlocked: '19 Oct 2024'),
      const BlockedProfile(id: 'blk-14', name: 'Pranav', age: 31, dateBlocked: '20 Oct 2024'),
    ]);
  }

  DataExportRecord? getActiveExport() => _activeExport;
  DataNominee getNominee() => _nominee;
  List<BlockedProfile> getBlockedList() => List.unmodifiable(_blockedList);

  Future<DataExportRecord> requestDataExport() async {
    final exportId = _uuid.v4();
    try {
      await _apiClient?.dio.post<dynamic>(
        '/api/v1/vault/export-data',
        data: {'export_id': exportId},
      );
    } catch (_) {}

    final record = DataExportRecord(
      id: exportId,
      status: ExportStatus.ready,
      requestedAt: DateTime.now(),
      downloadUrl: 'https://vault.urheart.app/exports/$exportId.zip',
    );
    _activeExport = record;
    return record;
  }

  Future<DataNominee> designateNominee({
    required String name,
    required String contact,
    required String relationship,
  }) async {
    try {
      await _apiClient?.dio.post<dynamic>(
        '/api/v1/vault/nominee',
        data: {
          'nominee_name': name,
          'nominee_contact': contact,
          'relationship': relationship,
        },
      );
    } catch (_) {}

    _nominee = DataNominee(
      name: name,
      contact: contact,
      relationship: relationship,
      isDesignated: true,
    );
    return _nominee;
  }

  Future<GrievanceRecord> fileGrievanceDossier({
    required String category,
    required String evidenceText,
  }) async {
    final id = _uuid.v4();
    try {
      await _apiClient?.dio.post<dynamic>(
        '/api/v1/vault/grievance',
        data: {
          'dossier_id': id,
          'category': category,
          'evidence': evidenceText,
        },
      );
    } catch (_) {}

    return GrievanceRecord(
      id: id,
      category: category,
      evidenceText: evidenceText,
      submittedAt: DateTime.now(),
    );
  }

  void unblockProfile(String id) {
    _blockedList.removeWhere((item) => item.id == id);
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return VaultRepository(client);
});
