import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'feed_candidate_model.dart';

export 'feed_candidate_model.dart';


class CandidateProfileModel {
  final String id;
  final String fullName;
  final int age;
  final String gender;
  final String city;
  final String bio;
  final int distanceKm;
  final String distanceBadge;
  final bool kycStatus;
  final int streakCount;
  final List<String> interests;
  final List<CandidatePhotoModel> photos;

  CandidateProfileModel({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.city,
    required this.bio,
    required this.distanceKm,
    this.distanceBadge = 'Nearby 5 km',
    required this.kycStatus,
    required this.streakCount,
    required this.interests,
    required this.photos,
  });

  String get primaryPhotoUrl {
    if (photos.isNotEmpty && photos.first.photoUrl.isNotEmpty) {
      return photos.first.photoUrl;
    }
    return '';
  }

  FeedCandidateModel toFeedCandidate() {
    return FeedCandidateModel(
      userId: id,
      fullName: fullName,
      city: city,
      detectedLocality: city,
      distanceKm: distanceKm,
      gender: gender,
      bio: bio,
      streakCount: streakCount,
      photos: photos,
    );
  }

  factory CandidateProfileModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    final rawInterests = json['interests'] as List<dynamic>? ?? [];
    final distKm = json['distance_km'] as int? ?? 5;

    return CandidateProfileModel(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'User').toString(),
      age: json['age'] as int? ?? 22,
      gender: (json['gender'] ?? 'unknown').toString(),
      city: (json['city'] ?? 'City').toString(),
      bio: (json['bio'] ?? '').toString(),
      distanceKm: distKm,
      distanceBadge: json['distance_badge'] as String? ?? 'Nearby $distKm km',
      kycStatus: json['kyc_status'] as bool? ?? false,
      streakCount: json['streak_count'] as int? ?? 0,
      interests: rawInterests.map((e) => e.toString()).toList(),
      photos: rawPhotos
          .map((p) => CandidatePhotoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SwipeResult {
  final String targetUserId;
  final String swipeType;
  final bool isMatch;
  final String? matchId;
  final bool whatsappUnlocked;
  final int? remainingDmTokens;

  SwipeResult({
    required this.targetUserId,
    required this.swipeType,
    required this.isMatch,
    this.matchId,
    required this.whatsappUnlocked,
    this.remainingDmTokens,
  });

  factory SwipeResult.fromJson(Map<String, dynamic> json) {
    return SwipeResult(
      targetUserId: json['target_user_id'] as String? ?? '',
      swipeType: json['swipe_type'] as String? ?? '',
      isMatch: json['is_match'] as bool? ?? false,
      matchId: json['match_id'] as String?,
      whatsappUnlocked: json['whatsapp_unlocked'] as bool? ?? false,
      remainingDmTokens: json['remaining_dm_tokens'] as int?,
    );
  }
}

class FeedRepository {
  final Dio _client;

  FeedRepository({Dio? client})
      : _client = client ?? createApiClient(baseUrl: EnvConfig.apiBaseUrl);

  /// Fetch candidate cards from backend GET /api/v1/feed with optional coordinates and city
  Future<List<CandidateProfileModel>> getCandidates({
    int limit = 20,
    double? lat,
    double? lon,
    String? city,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (lat != null) queryParams['lat'] = lat;
      if (lon != null) queryParams['lon'] = lon;
      if (city != null && city.isNotEmpty) queryParams['city'] = city;

      final response = await _client.get(
        '/api/v1/feed',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> candidatesJson;
        if (response.data is List) {
          candidatesJson = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['candidates'] != null) {
          candidatesJson = response.data['candidates'] as List<dynamic>;
        } else {
          candidatesJson = [];
        }
        return candidatesJson
            .map((c) => CandidateProfileModel.fromJson(c as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('FeedRepository.getCandidates error: $e');
      rethrow;
    }
  }

  /// Submit swipe action (like, pass, direct_dm) to POST /api/v1/feed/swipe
  Future<SwipeResult> submitSwipe({
    required String targetUserId,
    required String swipeType,
  }) async {
    try {
      final response = await _client.post(
        '/api/v1/feed/swipe',
        data: {
          'target_user_id': targetUserId,
          'swipe_type': swipeType,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return SwipeResult.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to record swipe: ${response.statusCode}');
    } catch (e) {
      debugPrint('FeedRepository.submitSwipe error: $e');
      rethrow;
    }
  }
}
