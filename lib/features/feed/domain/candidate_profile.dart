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
  final String aiInsight;
  final String intentQuote;
  final List<String> interests;
  final String avatarUrl;
  final List<String> photoUrls;
  final List<String> blurHashes;
  final bool isVerified;
  final bool isOnline;
  final String? voiceSparkUrl;
  final String? voiceSparkPrompt;
  final double voiceSparkDuration;
  final bool isVoiceVerified;
  final bool isPhotoVeiled;
  final bool isPhotoUnlocked;
  final String photoRevealStatus;

  const CandidateProfile({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.lookingFor,
    required this.locationName,
    required this.distanceKm,
    required this.resonanceScore,
    this.aiInsight = 'A shared reverence for quiet reflection connects your paths.',
    required this.intentQuote,
    required this.interests,
    this.avatarUrl = '',
    required this.photoUrls,
    required this.blurHashes,
    this.isVerified = false,
    this.isOnline = true,
    this.voiceSparkUrl,
    this.voiceSparkPrompt,
    this.voiceSparkDuration = 7.0,
    this.isVoiceVerified = false,
    this.isPhotoVeiled = false,
    this.isPhotoUnlocked = false,
    this.photoRevealStatus = 'none',
  });

  List<String> get photos => photoUrls;
  String get name => fullName;

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String? ?? json['avatar'] as String? ?? '';
    final rawPhotos = (json['photo_urls'] as List? ?? json['photos'] as List? ?? [])
        .map((e) => e?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final allPhotos = <String>[];
    if (avatar.trim().isNotEmpty) {
      allPhotos.add(avatar.trim());
    }
    for (final p in rawPhotos) {
      if (p.trim().isNotEmpty && !allPhotos.contains(p.trim())) {
        allPhotos.add(p.trim());
      }
    }

    final resolvedAvatar = avatar.trim().isNotEmpty ? avatar.trim() : (allPhotos.isNotEmpty ? allPhotos.first : '');
    final veiled = json['is_photo_veiled'] as bool? ?? false;

    return CandidateProfile(
      id: json['id'] as String? ?? json['user_id'] as String? ?? 'cand_${DateTime.now().millisecondsSinceEpoch}',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? 'Seeker',
      age: json['age'] as int? ?? 24,
      gender: json['gender'] as String? ?? 'Woman',
      lookingFor: json['looking_for'] as String? ?? 'Men',
      locationName: json['location_name'] as String? ?? json['location'] as String? ?? 'Ayodhya, UP',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 1.5,
      resonanceScore: json['resonance_score'] as int? ?? 90,
      aiInsight: json['ai_insight'] as String? ?? json['ai_resonance_insight'] as String? ?? 'A shared reverence for quiet reflection connects your paths.',
      intentQuote: json['intent_quote'] as String? ?? json['authentic_intention'] as String? ?? json['bio'] as String? ?? 'Authentic Intention: Seeking slow conversations.',
      interests: List<String>.from(json['interests'] as List? ?? json['tags'] as List? ?? ['Mindfulness', 'Presence']),
      avatarUrl: resolvedAvatar,
      photoUrls: allPhotos,
      blurHashes: List<String>.from(json['blur_hashes'] as List? ?? ['L6PZfSi_.AyE_3t7t7R**0o#DgR4']),
      isVerified: json['is_verified'] as bool? ?? json['is_kyc_verified'] as bool? ?? json['kyc_status'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? true,
      voiceSparkUrl: json['voice_spark_url'] as String?,
      voiceSparkPrompt: json['voice_spark_prompt'] as String?,
      voiceSparkDuration: (json['voice_spark_duration'] as num?)?.toDouble() ?? 7.0,
      isVoiceVerified: json['is_voice_verified'] as bool? ?? false,
      isPhotoVeiled: veiled,
      isPhotoUnlocked: json['is_photo_unlocked'] as bool? ?? (!veiled),
      photoRevealStatus: json['photo_reveal_status'] as String? ?? 'none',
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
    String? aiInsight,
    String? intentQuote,
    List<String>? interests,
    String? avatarUrl,
    List<String>? photoUrls,
    List<String>? blurHashes,
    bool? isVerified,
    bool? isOnline,
    String? voiceSparkUrl,
    String? voiceSparkPrompt,
    double? voiceSparkDuration,
    bool? isVoiceVerified,
    bool? isPhotoVeiled,
    bool? isPhotoUnlocked,
    String? photoRevealStatus,
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
      aiInsight: aiInsight ?? this.aiInsight,
      intentQuote: intentQuote ?? this.intentQuote,
      interests: interests ?? this.interests,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      blurHashes: blurHashes ?? this.blurHashes,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      voiceSparkUrl: voiceSparkUrl ?? this.voiceSparkUrl,
      voiceSparkPrompt: voiceSparkPrompt ?? this.voiceSparkPrompt,
      voiceSparkDuration: voiceSparkDuration ?? this.voiceSparkDuration,
      isVoiceVerified: isVoiceVerified ?? this.isVoiceVerified,
      isPhotoVeiled: isPhotoVeiled ?? this.isPhotoVeiled,
      isPhotoUnlocked: isPhotoUnlocked ?? this.isPhotoUnlocked,
      photoRevealStatus: photoRevealStatus ?? this.photoRevealStatus,
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
    'ai_insight': aiInsight,
    'ai_resonance_insight': aiInsight,
    'intent_quote': intentQuote,
    'authentic_intention': intentQuote,
    'bio': intentQuote,
    'interests': interests,
    'tags': interests,
    'avatar_url': avatarUrl.isNotEmpty ? avatarUrl : (photoUrls.isNotEmpty ? photoUrls.first : ''),
    'avatar': avatarUrl.isNotEmpty ? avatarUrl : (photoUrls.isNotEmpty ? photoUrls.first : ''),
    'photos': photoUrls,
    'photo_urls': photoUrls,
    'blur_hashes': blurHashes,
    'kyc_status': isVerified,
    'is_verified': isVerified,
    'is_online': isOnline,
    'voice_spark_url': voiceSparkUrl,
    'voice_spark_prompt': voiceSparkPrompt,
    'voice_spark_duration': voiceSparkDuration,
    'is_voice_verified': isVoiceVerified,
    'is_photo_veiled': isPhotoVeiled,
    'is_photo_unlocked': isPhotoUnlocked,
    'photo_reveal_status': photoRevealStatus,
  };

  static bool checkOrientationShield({
    required String userGender,
    required String userInterestedIn,
    required String targetGender,
    required String targetInterestedIn,
    bool targetIsIncognito = false,
  }) {
    if (targetIsIncognito) return false;
    if (userGender.trim().isEmpty) return true;

    final normTargetGender = _normalizeGender(targetGender);
    final normUserGender = _normalizeGender(userGender);
    final normUserInterest = _normalizeInterest(userInterestedIn);
    final normTargetInterest = _normalizeInterest(targetInterestedIn);

    // Does user want to see this candidate's gender?
    final userWantsTarget = normUserInterest == 'everyone' ||
        normTargetGender == normUserInterest;
    // Does candidate want to see user's gender?
    final targetWantsUser = normTargetInterest == 'everyone' ||
        normUserGender == normTargetInterest;

    return userWantsTarget && targetWantsUser;
  }

  static String _normalizeGender(String g) {
    final lower = g.trim().toLowerCase();
    if (['man', 'men', 'male'].contains(lower)) return 'men';
    if (['woman', 'women', 'female'].contains(lower)) return 'women';
    return lower; // non-binary, other, etc.
  }

  static String _normalizeInterest(String i) {
    final lower = i.trim().toLowerCase();
    if (['man', 'men', 'male'].contains(lower)) return 'men';
    if (['woman', 'women', 'female'].contains(lower)) return 'women';
    if (lower.contains(',') || lower == 'everyone' || lower.isEmpty) return 'everyone';
    return lower;
  }
}
