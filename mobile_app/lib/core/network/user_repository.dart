import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'secure_api_client.dart';

/// Strongly-typed User Profile Model matching the FastAPI backend `/api/v1/users/me` schema
class UserProfileModel {
  final String id;
  final String? clerkId;
  final String? email;
  final String? phoneNumber;
  final String fullName;
  final String firstName;
  final int? age;
  final String? dob;
  final String bio;
  final String areaName;
  final String villagePinCode;
  final String gender;
  final String interestedIn;
  final String intent;
  final List<String> photos;
  final String? photoUrl;
  final bool isVerified;
  final bool isAdmin;
  final bool isOnline;
  final bool isOnboarded;

  UserProfileModel({
    required this.id,
    this.clerkId,
    this.email,
    this.phoneNumber,
    required this.fullName,
    required this.firstName,
    this.age,
    this.dob,
    required this.bio,
    required this.areaName,
    required this.villagePinCode,
    required this.gender,
    required this.interestedIn,
    required this.intent,
    required this.photos,
    this.photoUrl,
    required this.isVerified,
    required this.isAdmin,
    required this.isOnline,
    required this.isOnboarded,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final photosList = <String>[];
    if (json['photos'] is List) {
      for (final p in json['photos']) {
        if (p is String && p.isNotEmpty) {
          photosList.add(p);
        }
      }
    }
    if (photosList.isEmpty && json['photo_url'] != null) {
      photosList.add(json['photo_url'] as String);
    }

    return UserProfileModel(
      id: json['id'] ?? json['user_id'] ?? '',
      clerkId: json['clerk_id'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      fullName: json['full_name'] ?? 'User',
      firstName: json['first_name'] ?? (json['full_name'] != null ? (json['full_name'] as String).split(' ').first : 'User'),
      age: json['age'] as int?,
      dob: json['dob'] as String?,
      bio: json['bio'] ?? '',
      areaName: json['area_name'] ?? 'Ayodhya',
      villagePinCode: json['village_pin_code'] ?? '224001',
      gender: json['gender'] ?? 'male',
      interestedIn: json['interested_in'] ?? 'female',
      intent: json['intent'] ?? 'casual',
      photos: photosList,
      photoUrl: json['photo_url'] as String? ?? (photosList.isNotEmpty ? photosList.first : null),
      isVerified: json['is_verified'] == true,
      isAdmin: json['is_admin'] == true,
      isOnline: json['is_online'] == true,
      isOnboarded: json['is_onboarded'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clerk_id': clerkId,
    'email': email,
    'phone_number': phoneNumber,
    'full_name': fullName,
    'first_name': firstName,
    'age': age,
    'dob': dob,
    'bio': bio,
    'area_name': areaName,
    'village_pin_code': villagePinCode,
    'gender': gender,
    'interested_in': interestedIn,
    'intent': intent,
    'photos': photos,
    'photo_url': photoUrl,
    'is_verified': isVerified,
    'is_admin': isAdmin,
    'is_online': isOnline,
    'is_onboarded': isOnboarded,
  };
}

/// User Profile Repository connecting Flutter with FastAPI backend
class UserRepository {
  final SecureApiClient _apiClient;

  UserRepository({SecureApiClient? apiClient})
      : _apiClient = apiClient ?? SecureApiClient.instance;

  /// Fetches the authenticated user's profile from the backend (`GET /api/v1/users/me`)
  /// The [ClerkAuthInterceptor] automatically attaches the active Clerk Bearer token.
  Future<UserProfileModel> fetchCurrentUserProfile() => fetchUserProfile();

  /// Fetches the authenticated user's profile from the backend (`GET /api/v1/users/me`)
  Future<UserProfileModel> fetchUserProfile() async {
    try {
      final response = await _apiClient.get('/users/me');

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        if (rawData is Map<String, dynamic>) {
          final profileMap = rawData['data'] is Map<String, dynamic>
              ? rawData['data'] as Map<String, dynamic>
              : rawData;
          return UserProfileModel.fromJson(profileMap);
        }
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Invalid response format from /users/me',
      );
    } on DioException catch (dioErr) {
      if (kDebugMode) {
        print('❌ [UserRepository.fetchUserProfile] Failed: ${dioErr.response?.data ?? dioErr.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UserRepository.fetchUserProfile] Unexpected error: $e');
      }
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Updates the authenticated user's dating profile (`PUT /api/v1/users/me`)
  Future<UserProfileModel> updateUserProfile({
    String? fullName,
    String? bio,
    String? dob,
    String? gender,
    String? interestedIn,
    String? intent,
    String? areaName,
    String? villagePinCode,
    bool? isLocationMasked,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (dob != null) 'dob': dob,
        if (gender != null) 'gender': gender,
        if (interestedIn != null) 'interested_in': interestedIn,
        if (intent != null) 'intent': intent,
        if (areaName != null) 'area_name': areaName,
        if (villagePinCode != null) 'village_pin_code': villagePinCode,
        if (isLocationMasked != null) 'is_location_masked': isLocationMasked,
      };

      final response = await _apiClient.put(
        '/users/me',
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        if (rawData is Map<String, dynamic>) {
          final profileMap = rawData['data'] is Map<String, dynamic>
              ? rawData['data'] as Map<String, dynamic>
              : rawData;
          return UserProfileModel.fromJson(profileMap);
        }
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Invalid response format from PUT /users/me',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UserRepository.updateUserProfile] Failed: $e');
      }
      rethrow;
    }
  }

  /// Synchronizes Clerk session with FastAPI backend and registers FCM token (`POST /api/v1/auth/clerk-sync`)
  Future<Map<String, dynamic>> syncClerkUserSession({
    String? fcmToken,
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/clerk-sync',
        data: {
          if (fcmToken != null) 'fcm_token': fcmToken,
          if (deviceId != null) 'device_id': deviceId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
          return raw['data'] as Map<String, dynamic>;
        }
      }
      return {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ [UserRepository.syncClerkUserSession] Failed: $e');
      }
      rethrow;
    }
  }
}
