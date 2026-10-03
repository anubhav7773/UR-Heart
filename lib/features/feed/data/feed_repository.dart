import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../domain/candidate_profile.dart';

export '../domain/candidate_profile.dart';

/// Result container for discovery deck candidate cards and user balance quota
class DiscoveryDeckResponse {
  final List<CandidateProfile> candidates;
  final int? swipesRemaining;
  final int? directLettersCount;

  const DiscoveryDeckResponse({
    required this.candidates,
    this.swipesRemaining,
    this.directLettersCount,
  });
}

/// Result container for completed swipe action
class SwipeResult {
  final int swipesRemaining;
  final int? directLettersCount;
  final bool isMatch;
  final String? matchId;

  const SwipeResult({
    required this.swipesRemaining,
    this.directLettersCount,
    this.isMatch = false,
    this.matchId,
  });
}

/// Data repository for discovery feed, swipe actions, and pass vault
class FeedRepository {
  final Dio _dio;
  int? _lastSwipesRemaining;
  int? _lastDirectLettersCount;

  int? get lastSwipesRemaining => _lastSwipesRemaining;
  int? get lastDirectLettersCount => _lastDirectLettersCount;

  FeedRepository([Dio? dio]) : _dio = dio ?? Dio();

  /// Fetches real reciprocal discovery candidates from Supabase/PostgreSQL.
  /// Zero synthetic mock fallback.
  Future<List<CandidateProfile>> getDiscoveryFeed({
    int limit = 20,
    String? cursor,
  }) async {
    final deck = await fetchDiscoveryDeck(limit: limit, cursor: cursor);
    return deck.candidates;
  }

  /// Full 360-degree discovery deck fetch with live quota synchronization
  Future<DiscoveryDeckResponse> fetchDiscoveryDeck({
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/discovery/feed',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );

      final Map<String, dynamic> body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'candidates': response.data};

      final List<dynamic> data = body['candidates'] as List<dynamic>? ?? [];
      final candidates = data.map((json) => CandidateProfile.fromJson(json as Map<String, dynamic>)).toList();
      final swipes = body['swipes_remaining'] as int?;
      final letters = body['direct_letters_count'] as int?;
      _lastSwipesRemaining = swipes;
      _lastDirectLettersCount = letters;

      return DiscoveryDeckResponse(
        candidates: candidates,
        swipesRemaining: swipes,
        directLettersCount: letters,
      );
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Dispatches swipe action. Server returns verified remaining swipes and letters balances.
  Future<SwipeResult> recordSwipe({
    required String targetUserId,
    required String swipeType, // 'like', 'pass', 'superlike', 'direct'
    String? letterText,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/swipes',
        data: {
          'target_id': targetUserId,
          'swipe_type': swipeType,
          if (letterText != null && letterText.isNotEmpty) 'letter_text': letterText,
        },
      );

      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        final swipes = data['swipes_remaining'] as int? ?? 0;
        final letters = data['direct_letters_count'] as int?;
        final isMatch = data['is_match'] as bool? ?? false;
        final matchId = data['match_id'] as String?;
        _lastSwipesRemaining = swipes;
        if (letters != null) _lastDirectLettersCount = letters;

        return SwipeResult(
          swipesRemaining: swipes,
          directLettersCount: letters,
          isMatch: isMatch,
          matchId: matchId,
        );
      }
      return const SwipeResult(swipesRemaining: 0);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Retrieves all passed profiles from the Pass Vault (PostgreSQL).
  Future<List<dynamic>> getPassedProfiles() async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/swipes/passed');
      final data = response.data;
      if (data is Map<String, dynamic> && data['passed_candidates'] is List) {
        return data['passed_candidates'] as List<dynamic>;
      } else if (data is List) {
        return data;
      }
      return <dynamic>[];
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Restores passed profile from pass vault back to active deck.
  Future<bool> restorePassedProfile(String targetUserId) async {
    try {
      final response = await _dio.delete<dynamic>('/api/v1/swipes/pass/$targetUserId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    final status = e.response?.statusCode;
    if (status == 401) throw const UnauthorizedException();
    if (status == 404) throw const ResourceNotFoundException();
    throw ServerException(e.response?.data?['detail'] as String? ?? 'Sanctuary service error.');
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return FeedRepository(dioClient.dio);
});
