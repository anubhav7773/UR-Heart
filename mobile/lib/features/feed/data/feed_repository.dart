import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';

class CandidatePhotoModel {
  final int slotIndex;
  final String photoUrl;
  final String blurHash;

  CandidatePhotoModel({
    required this.slotIndex,
    required this.photoUrl,
    required this.blurHash,
  });

  factory CandidatePhotoModel.fromJson(Map<String, dynamic> json) {
    return CandidatePhotoModel(
      slotIndex: json['slot_index'] as int? ?? 1,
      photoUrl: json['photo_storage_path'] as String? ?? '',
      blurHash: json['blur_hash'] as String? ?? '',
    );
  }
}

class CandidateProfileModel {
  final String id;
  final String fullName;
  final int age;
  final String gender;
  final String city;
  final String bio;
  final int distanceKm;
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

  factory CandidateProfileModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    final rawInterests = json['interests'] as List<dynamic>? ?? [];

    return CandidateProfileModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'User',
      age: json['age'] as int? ?? 22,
      gender: json['gender'] as String? ?? 'unknown',
      city: json['city'] as String? ?? 'City',
      bio: json['bio'] as String? ?? '',
      distanceKm: json['distance_km'] as int? ?? 5,
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

  /// Fetch candidate cards from backend GET /api/v1/feed
  Future<List<CandidateProfileModel>> getCandidates({int limit = 20}) async {
    try {
      final response = await _client.get(
        '/api/v1/feed',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final candidatesJson = response.data['candidates'] as List<dynamic>? ?? [];
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
