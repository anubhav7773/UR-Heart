import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../domain/vault_models.dart';

export '../domain/vault_models.dart';

/// Repository orchestrating statutory DPDP exports, nominee records & grievance filings
class VaultRepository {
  final Dio _dio;

  DataExportRecord? _activeExport;
  DataNominee _nominee = const DataNominee();
  final List<BlockedProfile> _blockedList = [];

  VaultRepository([Dio? dio]) : _dio = dio ?? Dio();

  DataExportRecord? getActiveExport() => _activeExport;
  DataNominee getNominee() => _nominee;
  List<BlockedProfile> getBlockedList() => List.unmodifiable(_blockedList);

  /// DPDP Sec 11: Initiates data portability export. Zero fake zip generation.
  Future<DataExportRecord> requestDataExport() async {
    try {
      final response = await _dio.post<dynamic>('/api/v1/vault/export-data');
      final data = response.data as Map<String, dynamic>;
      final ticket = DataExportTicket.fromJson(data);

      final record = DataExportRecord(
        id: ticket.requestId,
        status: ExportStatus.processing,
        requestedAt: DateTime.now(),
        downloadUrl: null,
        expiresText: 'Valid for ${ticket.validDays} days upon completion',
      );
      _activeExport = record;
      return record;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Polls async export compilation status
  Future<DataExportStatus> checkExportStatus(String requestId) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/vault/export-status/$requestId');
      return DataExportStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// DPDP Sec 14: Persists legal nominee to Supabase public.data_nominees
  Future<DataNominee> designateNominee({
    required String name,
    required String contact,
    required String relationship,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/vault/nominee',
        data: {
          'name': name.trim(),
          'phone': contact.trim(),
          'relationship': relationship.trim(),
        },
      );
      if (response.statusCode == 200) {
        _nominee = DataNominee(
          name: name.trim(),
          contact: contact.trim(),
          relationship: relationship.trim(),
          isDesignated: true,
        );
        return _nominee;
      }
      throw const ServerException('Failed to designate data nominee.');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// IT Rules 2021 Rule 3(2): Files statutory grievance ticket into database
  Future<GrievanceReceipt> fileGrievanceDossier({
    String? reportedUserId,
    String? category,
    String? violationCategory,
    String? evidenceText,
    String? evidence,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/vault/grievance',
        data: {
          if (reportedUserId != null) 'reported_user_id': reportedUserId,
          'violation_category': violationCategory ?? category ?? 'harassment',
          'evidence_text': (evidenceText ?? evidence ?? '').trim(),
        },
      );
      return GrievanceReceipt.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches real blocked users perimeter from Supabase
  Future<List<BlockedUserProfile>> fetchBlockedUsers() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/vault/blocked');
      final dynamic body = response.data;
      final List<dynamic> list = body is Map<String, dynamic>
          ? (body['blocked_users'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final parsed = list.map((json) => BlockedUserProfile.fromJson(json as Map<String, dynamic>)).toList();
      _blockedList
        ..clear()
        ..addAll(parsed);
      return parsed;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Removes user from blocked perimeter in database
  Future<bool> unblockUser(String blockedUserId) async {
    try {
      final response = await _dio.delete<dynamic>('/api/v1/vault/blocked/$blockedUserId');
      if (response.statusCode == 200) {
        _blockedList.removeWhere((item) => item.id == blockedUserId);
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void unblockProfile(String id) {
    unblockUser(id);
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    throw ServerException(e.response?.data?['detail'] as String? ?? 'Statutory vault error.');
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VaultRepository(dioClient.dio);
});
