import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../domain/resonance_models.dart';

export '../domain/resonance_models.dart';

class ResonancesRepository {
  final Dio _dio;

  ResonancesRepository([Dio? dio]) : _dio = dio ?? Dio();

  /// Fetches real inbound likes targeting the authenticated user.
  Future<List<IncomingLikeProfile>> fetchIncomingLikes() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/resonances/likes');
      final dynamic body = response.data;
      final List<dynamic> data = body is Map<String, dynamic>
          ? (body['likes'] as List<dynamic>? ?? body['data'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final List<IncomingLikeProfile> results = [];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          try {
            results.add(IncomingLikeProfile.fromJson(item));
          } catch (_) {}
        }
      }
      return results;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches verified mutual connection pairs from public.matches.
  Future<List<MutualConnection>> fetchMutualConnections() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/resonances/mutual');
      final dynamic body = response.data;
      final List<dynamic> data = body is Map<String, dynamic>
          ? (body['connections'] as List<dynamic>? ?? body['data'] as List<dynamic>? ?? [])
          : (body as List<dynamic>? ?? []);
      final List<MutualConnection> results = [];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          try {
            results.add(MutualConnection.fromJson(item));
          } catch (_) {}
        }
      }
      return results;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Reciprocal match creation. Returns generated match UUID or throws.
  Future<String> createMutualMatch(String peerUserId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/swipes',
        data: {'target_id': peerUserId, 'swipe_type': 'like'},
      );
      final dynamic body = response.data;
      final matchId = (body is Map<String, dynamic>) ? body['match_id'] as String? : null;
      if (matchId == null) throw const SanctuaryException('Mutual match generation pending.');
      return matchId;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    final data = e.response?.data;
    final message = data is Map ? (data['detail']?.toString() ?? 'Failed to synchronize resonances.') : (data?.toString() ?? 'Failed to synchronize resonances.');
    throw ServerException(message);
  }
}

final resonancesRepositoryProvider = Provider<ResonancesRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ResonancesRepository(dioClient.dio);
});
