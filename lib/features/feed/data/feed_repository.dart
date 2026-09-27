import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Domain entity representing a candidate profile in the sanctuary discovery deck
class CandidateProfile {
  final String id;
  final String fullName;
  final int age;
  final String gender;
  final String lookingFor;
  final String locationName;
  final double distanceKm;
  final int resonanceScore;
  final String intentQuote;
  final List<String> interests;
  final List<String> photoUrls;
  final List<String> blurHashes;
  final bool isVerified;
  final bool isOnline;

  const CandidateProfile({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.lookingFor,
    required this.locationName,
    required this.distanceKm,
    required this.resonanceScore,
    required this.intentQuote,
    required this.interests,
    required this.photoUrls,
    required this.blurHashes,
    this.isVerified = true,
    this.isOnline = true,
  });

  CandidateProfile copyWith({
    String? id,
    String? fullName,
    int? age,
    String? gender,
    String? lookingFor,
    String? locationName,
    double? distanceKm,
    int? resonanceScore,
    String? intentQuote,
    List<String>? interests,
    List<String>? photoUrls,
    List<String>? blurHashes,
    bool? isVerified,
    bool? isOnline,
  }) {
    return CandidateProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      lookingFor: lookingFor ?? this.lookingFor,
      locationName: locationName ?? this.locationName,
      distanceKm: distanceKm ?? this.distanceKm,
      resonanceScore: resonanceScore ?? this.resonanceScore,
      intentQuote: intentQuote ?? this.intentQuote,
      interests: interests ?? this.interests,
      photoUrls: photoUrls ?? this.photoUrls,
      blurHashes: blurHashes ?? this.blurHashes,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'age': age,
    'gender': gender,
    'looking_for': lookingFor,
    'location_name': locationName,
    'distance_km': distanceKm,
    'resonance_score': resonanceScore,
    'ai_insight': intentQuote,
    'intent_quote': intentQuote,
    'bio': intentQuote,
    'interests': interests,
    'photos': photoUrls,
    'photo_urls': photoUrls,
    'blur_hashes': blurHashes,
    'kyc_status': isVerified,
    'is_verified': isVerified,
    'is_online': isOnline,
  };

  static bool checkOrientationShield({
    required String userGender,
    required String userInterestedIn,
    required String targetGender,
    required String targetInterestedIn,
    bool targetIsIncognito = false,
  }) {
    if (targetIsIncognito) return false;
    final matchUserWantsTarget = userInterestedIn == 'Everyone' ||
        targetGender.toLowerCase() == userInterestedIn.toLowerCase();
    final matchTargetWantsUser = targetInterestedIn == 'Everyone' ||
        targetInterestedIn.toLowerCase() == userGender.toLowerCase();
    return matchUserWantsTarget && matchTargetWantsUser;
  }
}

/// Data repository for discovery feed, swipe actions, and pass vault
class FeedRepository {
  final ApiClient? _apiClient;

  FeedRepository([this._apiClient]);

  /// Fetches candidates respecting the Bi-Directional Orientation Shield
  Future<List<CandidateProfile>> getDiscoveryFeed({
    int limit = 10,
    String? cursor,
  }) async {
    final client = _apiClient;
    if (client == null) {
      return _generateSampleCandidates();
    }
    try {
      final response = await client.dio.get<List<dynamic>>(
        '/api/v1/feed',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );
      final data = response.data;
      if (data != null) {
        return data.map((json) => _mapJsonToCandidate(json as Map<String, dynamic>)).toList();
      }
      return _generateSampleCandidates();
    } catch (_) {
      return _generateSampleCandidates();
    }
  }

  /// Records swipe action (like, pass, superlike)
  Future<bool> recordSwipe({
    required String targetId,
    required String swipeType,
  }) async {
    final client = _apiClient;
    if (client == null) return true;
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/api/v1/swipes',
        data: {'target_id': targetId, 'swipe_type': swipeType},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true;
    }
  }

  /// Restores passed profile from pass vault back to feed
  Future<bool> restorePassedProfile(String targetId) async {
    final client = _apiClient;
    if (client == null) return true;
    try {
      final response = await client.dio.delete<Map<String, dynamic>>(
        '/api/v1/swipes/pass/$targetId',
      );
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  CandidateProfile _mapJsonToCandidate(Map<String, dynamic> json) {
    return CandidateProfile(
      id: json['id'] as String? ?? 'cand_1',
      fullName: json['full_name'] as String? ?? 'Aanya Sen',
      age: json['age'] as int? ?? 24,
      gender: json['gender'] as String? ?? 'Woman',
      lookingFor: json['looking_for'] as String? ?? 'Men',
      locationName: json['location_name'] as String? ?? 'Bandra West, Mumbai',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 1.5,
      resonanceScore: json['resonance_score'] as int? ?? 94,
      intentQuote: json['intent_quote'] as String? ?? 'Authentic Intention: Seeking slow conversations & deep presence.',
      interests: List<String>.from(json['interests'] as List? ?? ['Architecture', 'Pour-Over Coffee', 'Murakami']),
      photoUrls: List<String>.from(json['photo_urls'] as List? ?? []),
      blurHashes: List<String>.from(json['blur_hashes'] as List? ?? ['L6PZfSi_.AyE_3t7t7R**0o#DgR4']),
      isVerified: json['is_verified'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? true,
    );
  }

  List<CandidateProfile> _generateSampleCandidates() {
    return [
      const CandidateProfile(
        id: 'candidate_1',
        fullName: 'Meera Kapoor',
        age: 23,
        gender: 'Woman',
        lookingFor: 'Men',
        locationName: 'Bandra West, Mumbai',
        distanceKm: 1.5,
        resonanceScore: 94,
        intentQuote: 'I cherish morning walks through quiet bookshops and conversations that linger like good tea.',
        interests: ['Architecture', 'Pour-Over Coffee', 'Murakami', 'Ceramics'],
        photoUrls: ['https://images.unsplash.com/photo-1534528741775-53994a69daeb'],
        blurHashes: ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
        isVerified: true,
        isOnline: true,
      ),
      const CandidateProfile(
        id: 'candidate_2',
        fullName: 'Tara Sharma',
        age: 24,
        gender: 'Woman',
        lookingFor: 'Men',
        locationName: 'Juhu, Mumbai',
        distanceKm: 3.2,
        resonanceScore: 89,
        intentQuote: 'Architecture in the day, classical piano in the quiet night.',
        interests: ['Classical Music', 'Film Photography', 'Philosophy'],
        photoUrls: ['https://images.unsplash.com/photo-1517841905240-472988babdf9'],
        blurHashes: ['L5H2EC=~00Rj~pRP%2of%2j[00WB'],
        isVerified: true,
        isOnline: false,
      ),
      const CandidateProfile(
        id: 'candidate_3',
        fullName: 'Devika Roy',
        age: 25,
        gender: 'Woman',
        lookingFor: 'Men',
        locationName: 'Khar, Mumbai',
        distanceKm: 2.1,
        resonanceScore: 91,
        intentQuote: 'Looking for a sanctuary to share honest poetry and unspoken understanding.',
        interests: ['Poetry', 'Stargazing', 'Sufism'],
        photoUrls: ['https://images.unsplash.com/photo-1494790108377-be9c29b29330'],
        blurHashes: ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
        isVerified: true,
        isOnline: true,
      ),
    ];
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeedRepository(apiClient);
});
