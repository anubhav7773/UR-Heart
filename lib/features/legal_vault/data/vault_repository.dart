import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// DPDP Sec 11: Fetches signed PDF dossier from backend, saves to local temp file, and triggers native save/share
  Future<bool> downloadAndShareArchive(String requestId) async {
    try {
      final endpoint = (requestId.isNotEmpty && requestId != 'exp-statutory-current')
          ? '/api/v1/vault/export-pdf/$requestId'
          : '/api/v1/vault/export-pdf';
      final response = await _dio.get<List<int>>(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );

      final pdfBytes = response.data;
      if (pdfBytes == null || pdfBytes.isEmpty) {
        return false;
      }

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/UR_Heart_Statutory_Data_Dossier.pdf');
      await file.writeAsBytes(pdfBytes, flush: true);

      final xfile = XFile(
        file.path,
        mimeType: 'application/pdf',
        name: 'UR_Heart_Statutory_Data_Dossier.pdf',
      );
      await Share.shareXFiles(
        [xfile],
        text: 'UR-Heart DPDP Act 2023 Statutory Data Export Dossier (PDF)',
      );
      return true;
    } catch (e) {
      debugPrint('[VaultRepository] PDF export download error: $e');
      return false;
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

  /// Tracks a specific statutory grievance ticket status and SLA countdown
  Future<Map<String, dynamic>> trackGrievanceTicket(String referenceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/vault/grievance/track/${referenceId.trim()}',
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
      throw const ServerException('Ticket not found or inaccessible.');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches all grievance tickets filed by the current user
  Future<List<Map<String, dynamic>>> fetchMyGrievances() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/vault/grievances');
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['grievances'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
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

  /// Adds user to blocked perimeter in database and local cache
  Future<bool> blockUser(String blockedUserId, {String reason = 'unspecified'}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/vault/blocked',
        data: {
          'blocked_user_id': blockedUserId,
          'reason': reason,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        final blockedList = prefs.getStringList('ur_heart_blocked_user_ids') ?? [];
        if (!blockedList.contains(blockedUserId)) {
          blockedList.add(blockedUserId);
          await prefs.setStringList('ur_heart_blocked_user_ids', blockedList);
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Removes user from blocked perimeter in database
  Future<bool> unblockUser(String blockedUserId) async {
    try {
      final response = await _dio.delete<dynamic>('/api/v1/vault/blocked/$blockedUserId');
      if (response.statusCode == 200) {
        _blockedList.removeWhere((item) => item.id == blockedUserId);
        final prefs = await SharedPreferences.getInstance();
        final blockedList = prefs.getStringList('ur_heart_blocked_user_ids') ?? [];
        blockedList.remove(blockedUserId);
        await prefs.setStringList('ur_heart_blocked_user_ids', blockedList);
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
