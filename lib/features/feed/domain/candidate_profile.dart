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

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    return CandidateProfile(
      id: json['id'] as String? ?? json['user_id'] as String? ?? 'cand_${DateTime.now().millisecondsSinceEpoch}',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? 'Seeker',
      age: json['age'] as int? ?? 24,
      gender: json['gender'] as String? ?? 'Woman',
      lookingFor: json['looking_for'] as String? ?? 'Men',
      locationName: json['location_name'] as String? ?? json['location'] as String? ?? 'Ayodhya, UP',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 1.5,
      resonanceScore: json['resonance_score'] as int? ?? 90,
      intentQuote: json['intent_quote'] as String? ?? json['bio'] as String? ?? 'Authentic Intention: Seeking slow conversations.',
      interests: List<String>.from(json['interests'] as List? ?? ['Architecture', 'Tea']),
      photoUrls: List<String>.from(json['photo_urls'] as List? ?? json['photos'] as List? ?? []),
      blurHashes: List<String>.from(json['blur_hashes'] as List? ?? ['L6PZfSi_.AyE_3t7t7R**0o#DgR4']),
      isVerified: json['is_verified'] as bool? ?? json['kyc_status'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? true,
    );
  }

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
