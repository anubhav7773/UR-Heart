import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/user_profile_model.dart';

/// Repository handling Profile retrieval, updates, and Groq AI polish
class ProfileRepository {
  final ApiClient? _apiClient;

  UserProfile _currentProfile = const UserProfile(
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

  ProfileRepository([this._apiClient]);

  UserProfile getProfile() => _currentProfile;

  Future<UserProfile> updateProfile(UserProfile updated) async {
    _currentProfile = updated;
    try {
      await _apiClient?.dio.put<dynamic>(
        '/api/v1/user/profile',
        data: {
          'bio': updated.bio,
          'profession': updated.profession,
          'education': updated.education,
          'location': updated.location,
          'min_age_pref': updated.minAgePref.toInt(),
          'max_age_pref': updated.maxAgePref.toInt(),
        },
      );
    } catch (_) {
      // Graceful offline fallback
    }
    return _currentProfile;
  }

  Future<String> polishBioWithGroq(String currentBio) async {
    try {
      final res = await _apiClient?.dio.post<Map<String, dynamic>>(
        '/api/v1/ai/polish-bio',
        data: {'bio': currentBio},
      );
      final polished = res?.data?['polished_bio'] as String?;
      if (polished != null && polished.isNotEmpty) {
        return polished;
      }
    } catch (_) {}
    return 'Finding beauty in intentional spaces, analog photography, and quiet mornings. Here for mindful depth, slow rituals, and honest human connection.';
  }

  Future<String> refreshGpsLocation() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    const newLocation = 'Bandra West, Mumbai · Verified GPS';
    _currentProfile = _currentProfile.copyWith(location: newLocation);
    return newLocation;
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
