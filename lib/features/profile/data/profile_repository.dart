import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/activity_logger_service.dart';
import '../../../core/services/real_gps_location_service.dart';
import '../domain/user_profile_model.dart';

/// Repository handling Profile retrieval, updates, EVA AI bio polish, and Real Hardware GPS
class ProfileRepository {
  final ApiClient? _apiClient;
  UserProfile _currentProfile;

  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  ProfileRepository([this._apiClient])
      : _currentProfile = _defaultProfile() {
    loadProfileFromStorage();
  }

  static UserProfile _defaultProfile() => const UserProfile(
        id: 'user-self',
        fullName: 'Aanya Sharma',
        email: 'aanya.sharma@sanctuary.in',
        age: 22,
        dobVerificationPill: '14 Oct 2002 · LOCKED & VERIFIED',
        gender: 'Woman',
        interestedIn: 'Men',
        maskedWhatsApp: '+91 98765 ***** · ENCRYPTED',
        memberSinceText: 'Sanctuary Member since Oct 2024',
        hasVerifiedCrest: true,
        location: 'Bandra West, Mumbai',
        bio:
            'Architect passionate about quiet libraries, analog film, and pour-over coffee. Searching for slow, honest conversations that transcend algorithms.',
        profession: 'Architectural Conservator',
        education: 'CEPT University, Ahmedabad',
        minAgePref: 21.0,
        maxAgePref: 29.0,
        avatarUrl: '',
        momentPhotos: ['', '', '', ''],
      );

  UserProfile getProfile() => _currentProfile;

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
      final isKyc = prefs.getBool('profile_is_kyc_verified') ?? true;
      final savedBridgePlatform =
          prefs.getString('profile_contact_bridge_platform');
      final savedBridgeHandle = prefs.getString('profile_contact_bridge_handle');

      // Photos from slots
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

  Future<UserProfile> updateProfile(UserProfile updated) async {
    _currentProfile = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_bio', updated.bio);
      await prefs.setString('profile_profession', updated.profession);
      await prefs.setString('profile_education', updated.education);
      await prefs.setString('profile_location', updated.location);

      await _apiClient?.dio.put<dynamic>(
        ApiEndpoints.userProfile,
        data: {
          'bio': updated.bio,
          'profession': updated.profession,
          'education': updated.education,
          'location': updated.location,
          'min_age_pref': updated.minAgePref.toInt(),
          'max_age_pref': updated.maxAgePref.toInt(),
        },
      );

      await ActivityLogger.log(
        category: 'PROFILE',
        action: 'PROFILE_UPDATED',
        details: {'name': updated.fullName, 'location': updated.location},
      );
    } catch (_) {
      // Graceful offline fallback
    }
    return _currentProfile;
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
      final res = await _apiClient?.dio.post<Map<String, dynamic>>(
        ApiEndpoints.aiPolishBio,
        data: {
          'raw_bio': rawText,
          'intent': 'mindful',
        },
      );
      final polished = res?.data?['polished_bio'] as String?;
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
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProfileRepository(client);
});
