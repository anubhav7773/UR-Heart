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
import '../../../core/storage/secure_session_storage.dart';
import '../domain/user_profile_model.dart';

export '../domain/user_profile_model.dart';

/// Repository handling Profile retrieval, updates, EVA AI bio polish, and Real Hardware GPS
class ProfileRepository {
  final ApiClient? _apiClient;
  final Dio? _dio;
  UserProfile _currentProfile;

  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static UserProfile? _staticPrewarmedProfile;

  ProfileRepository([this._apiClient, this._dio])
      : _currentProfile = _staticPrewarmedProfile ?? _emptyInitialProfile() {
    loadProfileFromStorage();
  }

  /// Hydrates static in-memory profile synchronously from SharedPreferences during app startup
  static void prewarmStatic(SharedPreferences prefs) {
    try {
      final activeUserId = prefs.getString('ur_heart_user_id') ?? prefs.getString('profile_user_id');

      // 1. Try user-specific JSON cache
      if (activeUserId != null && activeUserId.isNotEmpty) {
        final userJsonStr = prefs.getString('cached_profile_json_$activeUserId');
        if (userJsonStr != null && userJsonStr.isNotEmpty) {
          final decoded = jsonDecode(userJsonStr) as Map<String, dynamic>;
          final prof = UserProfile.fromJson(decoded);
          if (prof.isLoaded) {
            _staticPrewarmedProfile = prof;
            return;
          }
        }
      }

      // 2. Try active profile JSON cache
      final activeJsonStr = prefs.getString('cached_profile_json_active');
      if (activeJsonStr != null && activeJsonStr.isNotEmpty) {
        final decoded = jsonDecode(activeJsonStr) as Map<String, dynamic>;
        final prof = UserProfile.fromJson(decoded);
        if (prof.isLoaded) {
          _staticPrewarmedProfile = prof;
          return;
        }
      }

      // 3. Fallback to individual legacy keys if present
      final savedName = prefs.getString('profile_full_name') ?? prefs.getString('ur_heart_user_name');
      if (savedName != null && savedName.trim().isNotEmpty) {
        final savedAge = prefs.getInt('profile_age') ?? prefs.getInt('ur_heart_user_age') ?? 0;
        final savedAvatar = prefs.getString('profile_photo_slot_1') ?? '';
        final isKyc = prefs.getBool('profile_is_kyc_verified') ?? false;
        final moments = ['', '', '', ''];
        for (int i = 2; i <= 5; i++) {
          final slotPath = prefs.getString('profile_photo_slot_$i');
          if (slotPath != null && (slotPath.startsWith('http') || File(slotPath).existsSync())) {
            moments[i - 2] = slotPath;
          }
        }

        _staticPrewarmedProfile = UserProfile(
          id: activeUserId ?? '',
          fullName: savedName,
          email: prefs.getString('ur_heart_user_email') ?? '',
          age: savedAge,
          dobVerificationPill: prefs.getString('profile_dob') ?? '',
          gender: prefs.getString('profile_gender') ?? '',
          interestedIn: prefs.getString('profile_interested_in') ?? '',
          maskedWhatsApp: '',
          memberSinceText: 'Member of Sanctuary',
          hasVerifiedCrest: isKyc,
          location: prefs.getString('profile_location') ?? '',
          bio: prefs.getString('profile_bio') ?? '',
          profession: prefs.getString('profile_profession') ?? '',
          education: prefs.getString('profile_education') ?? '',
          minAgePref: 18.0,
          maxAgePref: 35.0,
          avatarUrl: (savedAvatar.startsWith('http') || File(savedAvatar).existsSync()) ? savedAvatar : '',
          momentPhotos: moments,
        );
      }
    } catch (e) {
      debugPrint('[ProfileRepository.prewarmStatic] notice: $e');
    }
  }

  Dio get dio => _dio ?? _apiClient?.dio ?? Dio();

  static UserProfile _emptyInitialProfile() => const UserProfile(
        id: '',
        fullName: '',
        email: '',
        age: 0,
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

  void reset() {
    _currentProfile = _emptyInitialProfile();
    _staticPrewarmedProfile = null;
  }

  static UserProfile getEmptyProfile() => _emptyInitialProfile();

  /// Fetches authenticated user's persona directly from PostgreSQL.
  Future<UserPersonaModel> fetchMyProfile() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/profile/me');
      final profile = UserPersonaModel.fromJson(response.data as Map<String, dynamic>);
      _currentProfile = profile;
      _staticPrewarmedProfile = profile;
      final prefs = await SharedPreferences.getInstance();
      if (profile.id.isNotEmpty) {
        await prefs.setString('profile_user_id', profile.id);
        await prefs.setString('cached_profile_json_${profile.id}', jsonEncode(profile.toJson()));
      }
      await prefs.setString('cached_profile_json_active', jsonEncode(profile.toJson()));
      if (profile.referralCode.isNotEmpty) {
        await prefs.setString('profile_referral_code', profile.referralCode);
        await prefs.setString('ur_heart_user_referral_code', profile.referralCode);
      }
      return profile;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetches another seeker's live profile, photos, and calculated resonance from PostgreSQL.
  Future<Map<String, dynamic>> fetchPeerProfile(String userId) async {
    try {
      final response = await dio.get<dynamic>('/api/v1/profile/$userId');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Redeems friend's referral code with backend
  Future<Map<String, dynamic>> redeemReferralCode(String code) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/profile/referral/redeem',
        data: {'referral_code': code.trim().toUpperCase()},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? 'Failed to redeem referral code.';
      throw Exception(detail);
    }
  }

  /// Restores user profile and DOB accurately from SharedPreferences
  Future<UserProfile> loadProfileFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final secureUserId = await SecureSessionStorage.instance.getUserId();
      final currentUserId = secureUserId ?? prefs.getString('ur_heart_user_id');
      final storedProfileUserId = prefs.getString('profile_user_id');

      // 1. Prioritize user-specific JSON cache for currentUserId
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final userCacheStr = prefs.getString('cached_profile_json_$currentUserId');
        if (userCacheStr != null && userCacheStr.isNotEmpty) {
          try {
            final profile = UserProfile.fromJson(jsonDecode(userCacheStr) as Map<String, dynamic>);
            if (profile.isLoaded) {
              _currentProfile = profile;
              _staticPrewarmedProfile = profile;
              return _currentProfile;
            }
          } catch (_) {}
        }
      }

      final bool isSameUser = (currentUserId != null &&
          currentUserId.isNotEmpty &&
          storedProfileUserId != null &&
          storedProfileUserId.isNotEmpty &&
          storedProfileUserId == currentUserId);

      // 2. Check active JSON cache if user IDs match or no previous mismatch
      if (isSameUser || storedProfileUserId == null || storedProfileUserId.isEmpty) {
        final activeCacheStr = prefs.getString('cached_profile_json_active');
        if (activeCacheStr != null && activeCacheStr.isNotEmpty) {
          try {
            final profile = UserProfile.fromJson(jsonDecode(activeCacheStr) as Map<String, dynamic>);
            if (profile.isLoaded) {
              _currentProfile = profile;
              _staticPrewarmedProfile = profile;
              return _currentProfile;
            }
          } catch (_) {}
        }
      }

      // If switching accounts or account mismatch, return empty profile only if no cache exists
      if (!isSameUser && (storedProfileUserId != null || currentUserId == null)) {
        if (_currentProfile.id.isNotEmpty && _currentProfile.id != currentUserId) {
          _currentProfile = _emptyInitialProfile();
        }
        return _currentProfile;
      }

      final savedName = prefs.getString('profile_full_name') ??
          prefs.getString('ur_heart_user_name');
      final savedDob = prefs.getString('profile_dob') ??
          prefs.getString('ur_heart_selected_dob');
      final savedAge = prefs.getInt('profile_age') ??
          prefs.getInt('ur_heart_user_age');
      final savedGender = prefs.getString('profile_gender');
      final savedInterestedIn = prefs.getString('profile_interested_in');
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
      if (isSameUser) {
        final slot1 = prefs.getString('profile_photo_slot_1');
        if (slot1 != null && (slot1.startsWith('http') || File(slot1).existsSync())) {
          avatar = slot1;
        }
        for (int i = 2; i <= 5; i++) {
          final slotPath = prefs.getString('profile_photo_slot_$i');
          if (slotPath != null && (slotPath.startsWith('http') || File(slotPath).existsSync())) {
            moments[i - 2] = slotPath;
          }
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
        gender: (savedGender != null && savedGender.isNotEmpty)
            ? savedGender
            : _currentProfile.gender,
        interestedIn: (savedInterestedIn != null && savedInterestedIn.isNotEmpty)
            ? savedInterestedIn
            : _currentProfile.interestedIn,
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

      if (_currentProfile.isLoaded) {
        _staticPrewarmedProfile = _currentProfile;
        await prefs.setString('cached_profile_json_active', jsonEncode(_currentProfile.toJson()));
        if (_currentProfile.id.isNotEmpty) {
          await prefs.setString('cached_profile_json_${_currentProfile.id}', jsonEncode(_currentProfile.toJson()));
        }
      }
    } catch (e) {
      debugPrint('[ProfileRepository] Error loading storage: $e');
    }
    return _currentProfile;
  }

  /// Persists edits directly to public.users table via PUT /api/v1/profile/me.
  Future<UserProfile> updateProfile(UserProfile updated) async {
    _currentProfile = updated;
    _staticPrewarmedProfile = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_bio', updated.bio);
      await prefs.setString('profile_profession', updated.profession);
      await prefs.setString('profile_education', updated.education);
      await prefs.setString('profile_location', updated.location);
      await prefs.setString('cached_profile_json_active', jsonEncode(updated.toJson()));
      if (updated.id.isNotEmpty) {
        await prefs.setString('cached_profile_json_${updated.id}', jsonEncode(updated.toJson()));
      }

      final response = await dio.put<dynamic>(
        '/api/v1/profile/me',
        data: {
          'bio': updated.bio,
          'profession': updated.profession,
          'education': updated.education,
          'location_name': updated.location,
          'gender': updated.gender,
          'interested_in': updated.interestedIn,
          'preferred_age_min': updated.minAgePref.toInt(),
          'preferred_age_max': updated.maxAgePref.toInt(),
          'photos': updated.momentPhotos,
          'avatar_url': updated.avatarUrl,
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
                    'You are EVA AI for UR-Heart mindful dating. '
                    'Transform the seeker\'s raw thoughts into an authentic, attractive first-person dating bio (35-50 words). '
                    'CRITICAL ZERO-CHATBOT POLICY: NEVER ask questions or write conversational chat prompts (no "Tell me...", no "What inspires you?", no "Ask me anything"). '
                    'Write strictly as their personal dating profile bio. Return ONLY the polished bio text, no explanations.'
              },
              {
                'role': 'user',
                'content':
                    'Write my 1st-person dating profile bio from these raw thoughts (NO questions, NO chatbot talk): "$rawText"'
              }
            ],
            'temperature': 0.75,
            'max_tokens': 140,
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

    // Dynamic poetic fallback rotation incorporating the user's specific words
    final fallbacks = [
      'Passionate about $rawText. Grounded in quiet rituals, genuine curiosity, and heartfelt presence.',
      'Drawn to $rawText — appreciating intentional conversations, slow mornings, and authentic connection.',
      '$rawText · Believer in slow connections, sincere laughter, and peaceful spaces.',
      'Guided by kindness and authentic depth. Inspired by $rawText · Seeking a mindful companion.',
    ];
    fallbacks.shuffle();
    return fallbacks.first;
  }

  Future<String> polishBioWithGroq(String currentBio) =>
      polishBioWithEvaAi(currentBio);

  /// Acquires Real Hardware GPS using anti-fraud positioning
  Future<String> refreshGpsLocation() async {
    final result = await RealGpsLocationService.acquireRealHardwareGps();
    if (result.isSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_location', result.formattedLocation);
      await prefs.setDouble('profile_gps_latitude', result.latitude);
      await prefs.setDouble('profile_gps_longitude', result.longitude);
      await prefs.setBool('profile_gps_verified', true);

      _currentProfile = _currentProfile.copyWith(location: result.formattedLocation);

      try {
        await dio.put<dynamic>(
          '/api/v1/profile/me',
          data: {
            'location_name': result.formattedLocation,
            'latitude': result.latitude,
            'longitude': result.longitude,
          },
        );
      } catch (_) {}

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

  Future<void> updateNightSlumber(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ur_heart_night_slumber', val);
      _currentProfile = _currentProfile.copyWith(nightSlumber: val);
      await _dio?.put<dynamic>(
        '/api/v1/user/preferences',
        data: {'night_slumber': val},
      );
    } catch (e) {
      debugPrint('[ProfileRepository] updateNightSlumber notice: $e');
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      throw const NetworkUnavailableException();
    }
    if (e.response?.statusCode == 401) throw const UnauthorizedException();
    final data = e.response?.data;
    final message = data is Map ? (data['detail']?.toString() ?? 'Profile synchronization failed.') : (data?.toString() ?? 'Profile synchronization failed.');
    throw ServerException(message);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final dioClient = ref.watch(dioClientProvider);
  return ProfileRepository(client, dioClient.dio);
});
