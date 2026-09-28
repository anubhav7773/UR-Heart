import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/sanctuary_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/activity_logger_service.dart';
import '../../../core/services/real_gps_location_service.dart';
import '../domain/user_profile_model.dart';

export '../domain/user_profile_model.dart';

/// Repository handling Profile retrieval, updates, EVA AI bio polish, and Real Hardware GPS
class ProfileRepository {
  final ApiClient? _apiClient;
  final Dio? _dio;
  UserProfile _currentProfile;

  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  ProfileRepository([this._apiClient, this._dio])
      : _currentProfile = _emptyInitialProfile() {
    loadProfileFromStorage();
  }

  Dio get dio => _dio ?? _apiClient?.dio ?? Dio();

  static UserProfile _emptyInitialProfile() => const UserProfile(
        id: '',
        fullName: '',
        email: '',
        age: 18,
        dobVerificationPill: '',
        gender: '',
        interestedIn: '',
        maskedWhatsApp: '',
        memberSinceText: '',
        hasVerifiedCrest: false,
        location: '',
        bio: '',
        profession: '',
        education: '',
        minAgePref: 18.0,
        maxAgePref: 35.0,
        avatarUrl: '',
        momentPhotos: ['', '', '', ''],
      );

  UserProfile getProfile() => _currentProfile;

  /// Fetches authenticated user's persona directly from PostgreSQL.
  Future<UserPersonaModel> fetchMyProfile() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/profile/me');
      final profile = UserPersonaModel.fromJson(response.data as Map<String, dynamic>);
      _currentProfile = profile;
      return profile;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Restores user profile and DOB accurately from SharedPreferences
  Future<UserProfile> loadProfileFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedName = prefs.getString('profile_full_name') ??
          prefs.getString('ur_heart_user_name');
      final savedDob = prefs.getString('profile_dob') ??
          prefs.getString('ur_heart_selected_dob');
      final savedAge = prefs.getInt('profile_age') ??
          prefs.getInt('ur_heart_user_age');
      final savedGender = prefs.getString('profile_gender');
      final savedLocation = prefs.getString('profile_location');
      final savedBio = prefs.getString('profile_bio');
      final savedProfession = prefs.getString('profile_profession');
      final savedEducation = prefs.getString('profile_education');
      final isKyc = prefs.getBool('profile_is_kyc_verified') ?? false;
      final savedBridgePlatform =
          prefs.getString('profile_contact_bridge_platform');
      final savedBridgeHandle = prefs.getString('profile_contact_bridge_handle');

      final List<String> moments = ['', '', '', ''];
      String avatar = '';
      final slot1 = prefs.getString('profile_photo_slot_1');
      if (slot1 != null && File(slot1).existsSync()) {
        avatar = slot1;
      }
      for (int i = 2; i <= 5; i++) {
        final slotPath = prefs.getString('profile_photo_slot_$i');
        if (slotPath != null && File(slotPath).existsSync()) {
          moments[i - 2] = slotPath;
        }
      }

      final pillText = (savedDob != null && savedDob.isNotEmpty)
          ? '$savedDob · LOCKED & VERIFIED'
          : _currentProfile.dobVerificationPill;

      String bridgeMasked = _currentProfile.maskedWhatsApp;
      if (savedBridgeHandle != null && savedBridgeHandle.isNotEmpty) {
        bridgeMasked = '$savedBridgePlatform: $savedBridgeHandle';
      }

      _currentProfile = _currentProfile.copyWith(
        fullName: (savedName != null && savedName.isNotEmpty)
            ? savedName
            : _currentProfile.fullName,
        age: savedAge ?? _currentProfile.age,
        dobVerificationPill: pillText,
        gender: savedGender ?? _currentProfile.gender,
        location: (savedLocation != null && savedLocation.isNotEmpty)
            ? savedLocation
            : _currentProfile.location,
        bio: (savedBio != null && savedBio.isNotEmpty)
            ? savedBio
            : _currentProfile.bio,
        profession: (savedProfession != null && savedProfession.isNotEmpty)
            ? savedProfession
            : _currentProfile.profession,
        education: (savedEducation != null && savedEducation.isNotEmpty)
            ? savedEducation
            : _currentProfile.education,
        hasVerifiedCrest: isKyc,
        maskedWhatsApp: bridgeMasked,
        avatarUrl: avatar.isNotEmpty ? avatar : _currentProfile.avatarUrl,
        momentPhotos: moments,
      );
    } catch (e) {
      debugPrint('[ProfileRepository] Error loading storage: $e');
    }
    return _currentProfile;
  }

  /// Persists edits directly to public.users table via PUT /api/v1/profile/me.
  Future<UserProfile> updateProfile(UserProfile updated) async {
    _currentProfile = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_bio', updated.bio);
      await prefs.setString('profile_profession', updated.profession);
      await prefs.setString('profile_education', updated.education);
      await prefs.setString('profile_location', updated.location);

      final response = await dio.put<dynamic>(
        '/api/v1/profile/me',
        data: {
          'bio': updated.bio,
          'profession': updated.profession,
          'education': updated.education,
          'location_name': updated.location,
          'preferred_age_min': updated.minAgePref.toInt(),
          'preferred_age_max': updated.maxAgePref.toInt(),
        },
      );

      if (response.statusCode != 200) {
        throw const ServerException('Profile update failed.');
      }

      await ActivityLogger.log(
        category: 'PROFILE',
        action: 'PROFILE_UPDATED',
        details: {'name': updated.fullName, 'location': updated.location},
      );
      return _currentProfile;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Refines bio using real EVA AI on Render via Groq LPU with direct Groq Cloud failover
  Future<String> polishBioWithEvaAi(String currentBio) async {
    final rawText = currentBio.trim();
    if (rawText.isEmpty) {
      return 'Mindful explorer appreciating intentional spaces, analog photography, and quiet mornings. Here for depth and honest human connection.';
    }

    await ActivityLogger.log(
      category: 'EVA_AI',
      action: 'BIO_POLISH_REQUESTED',
      details: {'input_length': rawText.length},
    );

    // Primary: Call Render Backend AI cluster
    try {
      final res = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.aiPolishBio,
        data: {
          'raw_bio': rawText,
          'intent': 'mindful',
        },
      );
      final polished = res.data?['polished_bio'] as String?;
      if (polished != null && polished.isNotEmpty) {
        await ActivityLogger.log(
          category: 'EVA_AI',
          action: 'BIO_POLISHED_RENDER_SUCCESS',
          details: {'output_length': polished.length},
        );
        return polished;
      }
    } catch (e) {
      debugPrint('[ProfileRepository] Render Bio polish fallback: $e');
    }

    // Secondary Failover: Direct Groq Cloud LPU endpoint
    if (_groqApiKey.isNotEmpty) {
      try {
        final groqUrl = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
        final groqResponse = await http.post(
          groqUrl,
          headers: {
            'Authorization': 'Bearer $_groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'llama-3.3-70b-versatile',
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are EVA AI, the poetic and mindful AI companion for UR-Heart dating sanctuary. '
                    'Rewrite the user bio with elegance, mindfulness, and authenticity. '
                    'Keep the user core interests unchanged. Return ONLY the polished bio text, no explanations.'
              },
              {
                'role': 'user',
                'content': 'Please polish this dating bio: "$rawText"'
              }
            ],
            'temperature': 0.7,
            'max_tokens': 120,
          }),
        ).timeout(const Duration(seconds: 8));

        if (groqResponse.statusCode == 200) {
          final data = jsonDecode(groqResponse.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content'] as String?;
            if (content != null && content.trim().isNotEmpty) {
              final cleaned = content.trim().replaceAll('"', '');
              await ActivityLogger.log(
                category: 'EVA_AI',
                action: 'BIO_POLISHED_GROQ_DIRECT_SUCCESS',
                details: {'output_length': cleaned.length},
              );
              return cleaned;
            }
          }
        }
      } catch (err) {
        debugPrint('[ProfileRepository] Direct Groq API error: $err');
      }
    }

    return '$rawText · Mindfully present, cherishing authentic conversation and intentional depth.';
  }

  Future<String> polishBioWithGroq(String currentBio) =>
      polishBioWithEvaAi(currentBio);

  /// Acquires Real Hardware GPS using anti-fraud positioning
  Future<String> refreshGpsLocation() async {
    final result = await RealGpsLocationService.acquireRealHardwareGps();
    if (result.isSuccess) {
      _currentProfile = _currentProfile.copyWith(location: result.formattedLocation);
      return result.formattedLocation;
    } else {
      return result.errorMessage ?? 'Unable to acquire genuine GPS';
    }
  }

  Future<void> updatePhotoSlot(int index, String url) async {
    final list = List<String>.from(_currentProfile.momentPhotos);
    if (index >= 0 && index < list.length) {
      list[index] = url;
      _currentProfile = _currentProfile.copyWith(momentPhotos: list);
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    throw ServerException(e.response?.data?['detail'] as String? ?? 'Profile synchronization failed.');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final dioClient = ref.watch(dioClientProvider);
  return ProfileRepository(client, dioClient.dio);
});
