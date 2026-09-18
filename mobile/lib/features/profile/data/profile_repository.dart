import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ur_heart/core/config/env_config.dart';
import 'package:ur_heart/core/network/api_client.dart';

class UserProfilePhoto {
  final int slotIndex;
  final String photoUrl;
  final String blurHash;

  UserProfilePhoto({
    required this.slotIndex,
    required this.photoUrl,
    required this.blurHash,
  });

  factory UserProfilePhoto.fromJson(Map<String, dynamic> json) {
    return UserProfilePhoto(
      slotIndex: json['slot_index'] as int? ?? 1,
      photoUrl: json['photo_url'] as String? ?? '',
      blurHash: json['blur_hash'] as String? ?? '',
    );
  }
}

class UserProfileData {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String city;
  final String bio;
  final int streakCount;
  final int rewardBalance;
  final bool kycStatus;
  final List<UserProfilePhoto> photos;

  UserProfileData({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.city,
    required this.bio,
    required this.streakCount,
    required this.rewardBalance,
    required this.kycStatus,
    this.photos = const [],
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    return UserProfileData(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? 'User',
      phoneNumber: json['phone_number'] as String? ?? '',
      city: json['city'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      streakCount: json['streak_count'] as int? ?? 0,
      rewardBalance: json['reward_balance'] as int? ?? 0,
      kycStatus: json['kyc_status'] as bool? ?? false,
      photos: rawPhotos
          .whereType<Map<String, dynamic>>()
          .map((p) => UserProfilePhoto.fromJson(p))
          .toList(),
    );
  }
}

class ProfileRepository {
  final Dio _client;

  ProfileRepository({Dio? client})
      : _client = client ?? createApiClient(baseUrl: EnvConfig.apiBaseUrl);

  /// Fetch user profile from GET /api/v1/users/profile
  Future<UserProfileData?> getProfile() async {
    try {
      final response = await _client.get('/api/v1/users/profile');
      if (response.statusCode == 200 && response.data != null) {
        return UserProfileData.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// One-Tap account erase per DPDP Act Section 8(7)
  Future<bool> eraseAccount() async {
    try {
      final response = await _client.post('/api/v1/safety/erase-account');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error erasing account: $e');
      rethrow;
    }
  }
}
