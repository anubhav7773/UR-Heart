/// Domain model for User Persona in Screen 11
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final int age;
  final String dobVerificationPill;
  final String gender;
  final String interestedIn;
  final String maskedWhatsApp;
  final String memberSinceText;
  final bool hasVerifiedCrest;
  final String location;
  final String bio;
  final String profession;
  final String education;
  final double minAgePref;
  final double maxAgePref;
  final String avatarUrl;
  final List<String> momentPhotos;
  final String referralCode;
  final int swipesRemaining;
  final int directLettersCount;
  final bool isAdFree;
  final bool nightSlumber;
  final String subscriptionTier;
  final int rewardBalance;
  final int streakCount;
  final int boostPoints;
  final int revealTokensCount;
  final int secondsRemaining;
  final String? voiceSparkUrl;
  final String? voiceSparkPrompt;
  final double voiceSparkDuration;
  final bool isVoiceVerified;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.age,
    required this.dobVerificationPill,
    required this.gender,
    required this.interestedIn,
    required this.maskedWhatsApp,
    required this.memberSinceText,
    required this.hasVerifiedCrest,
    required this.location,
    required this.bio,
    required this.profession,
    required this.education,
    required this.minAgePref,
    required this.maxAgePref,
    required this.avatarUrl,
    required this.momentPhotos,
    this.referralCode = '',
    this.swipesRemaining = 10,
    this.directLettersCount = 0,
    this.isAdFree = false,
    this.nightSlumber = false,
    this.subscriptionTier = 'free',
    this.rewardBalance = 0,
    this.streakCount = 0,
    this.boostPoints = 0,
    this.revealTokensCount = 0,
    this.secondsRemaining = 0,
    this.voiceSparkUrl,
    this.voiceSparkPrompt,
    this.voiceSparkDuration = 7.0,
    this.isVoiceVerified = false,
  });

  bool get isStreakActive => secondsRemaining > 0 && streakCount > 0;
  bool get isLoaded => fullName.trim().isNotEmpty;
  bool get isPlaceholder => !isLoaded;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'age': age,
    'dob': dobVerificationPill,
    'gender': gender,
    'interested_in': interestedIn,
    'contact_bridge_masked': maskedWhatsApp,
    'kyc_status': hasVerifiedCrest,
    'location_name': location,
    'bio': bio,
    'profession': profession,
    'education': education,
    'preferred_age_min': minAgePref,
    'preferred_age_max': maxAgePref,
    'avatar_url': avatarUrl,
    'photos': momentPhotos,
    'referral_code': referralCode,
    'swipes_remaining': swipesRemaining,
    'direct_letters_count': directLettersCount,
    'is_ad_free': isAdFree,
    'night_slumber': nightSlumber,
    'subscription_tier': subscriptionTier,
    'reward_balance': rewardBalance,
    'streak_count': streakCount,
    'boost_points': boostPoints,
    'reveal_tokens_count': revealTokensCount,
    'seconds_remaining': secondsRemaining,
    'voice_spark_url': voiceSparkUrl,
    'voice_spark_prompt': voiceSparkPrompt,
    'voice_spark_duration': voiceSparkDuration,
    'is_voice_verified': isVoiceVerified,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawAvatar = ((json['avatar_url'] ?? json['avatarUrl']) as String? ?? '').trim();
    final rawPhotos = (json['photos'] is List
            ? (json['photos'] as List<dynamic>)
            : (json['moment_photos'] is List
                ? (json['moment_photos'] as List<dynamic>)
                : (json['momentPhotos'] is List
                    ? (json['momentPhotos'] as List<dynamic>)
                    : const <dynamic>[])))
        .map((e) => e?.toString().trim() ?? '')
        .toList();

    String resolvedAvatar = rawAvatar;
    List<String> resolvedMoments = [];

    if (rawPhotos.length == 5) {
      // Legacy 5-slot structure: slot 1 is avatar, slots 2-5 are moments
      if (resolvedAvatar.isEmpty && rawPhotos[0].isNotEmpty) {
        resolvedAvatar = rawPhotos[0];
      }
      resolvedMoments = rawPhotos.sublist(1);
    } else {
      if (resolvedAvatar.isEmpty && rawPhotos.isNotEmpty) {
        resolvedAvatar = rawPhotos[0];
        resolvedMoments = rawPhotos.sublist(1);
      } else {
        // If photos contains the avatar at index 0, strip it to prevent duplicate display in Moments #1
        if (rawPhotos.isNotEmpty && rawPhotos[0] == resolvedAvatar) {
          resolvedMoments = rawPhotos.sublist(1);
        } else {
          resolvedMoments = List<String>.from(rawPhotos);
        }
      }
    }

    while (resolvedMoments.length < 4) {
      resolvedMoments.add('');
    }
    if (resolvedMoments.length > 4) {
      resolvedMoments = resolvedMoments.sublist(0, 4);
    }

    final name = (json['full_name'] ?? json['fullName']) as String? ?? '';
    final parsedAge = (json['age'] is num) ? (json['age'] as num).toInt() : 0;

    return UserProfile(
      id: json['id'] as String? ?? '',
      fullName: name,
      email: json['email'] as String? ?? '',
      age: parsedAge,
      dobVerificationPill: json['dob'] as String? ?? json['dobVerificationPill'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      interestedIn: (json['interested_in'] ?? json['interestedIn']) as String? ?? '',
      maskedWhatsApp: (json['contact_bridge_masked'] ?? json['maskedWhatsApp']) as String? ?? '',
      memberSinceText: json['memberSinceText'] as String? ?? 'Member of Sanctuary',
      hasVerifiedCrest: json['kyc_status'] as bool? ??
          (json['hasVerifiedCrest'] as bool? ??
              (json['is_kyc_verified'] as bool? ??
                  (json['is_kyc'] as bool? ?? false))),
      location: (json['location_name'] ?? json['location']) as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profession: json['profession'] as String? ?? '',
      education: json['education'] as String? ?? '',
      minAgePref: ((json['preferred_age_min'] ?? json['minAgePref']) as num?)?.toDouble() ?? 18.0,
      maxAgePref: ((json['preferred_age_max'] ?? json['maxAgePref']) as num?)?.toDouble() ?? 35.0,
      avatarUrl: resolvedAvatar,
      momentPhotos: resolvedMoments,
      referralCode: (json['referral_code'] ?? json['referralCode']) as String? ?? '',
      swipesRemaining: (json['swipes_remaining'] ?? json['swipesRemaining']) as int? ?? 10,
      directLettersCount: (json['direct_letters_count'] ?? json['directLettersCount']) as int? ?? 0,
      isAdFree: (json['is_ad_free'] ?? json['isAdFree']) as bool? ?? false,
      nightSlumber: (json['night_slumber'] ?? json['nightSlumber']) as bool? ?? false,
      subscriptionTier: (json['subscription_tier'] ?? json['subscriptionTier']) as String? ?? 'free',
      rewardBalance: (json['reward_balance'] ?? json['rewardBalance']) as int? ?? 0,
      streakCount: (json['streak_count'] ?? json['streakCount']) as int? ?? 0,
      boostPoints: (json['boost_points'] ?? json['boostPoints']) as int? ?? 0,
      revealTokensCount: (json['reveal_tokens_count'] ?? json['revealTokensCount']) as int? ?? 0,
      secondsRemaining: (json['streak_info'] is Map && json['streak_info']['seconds_remaining'] != null)
          ? (json['streak_info']['seconds_remaining'] as int)
          : ((json['seconds_remaining'] ?? json['secondsRemaining']) as int? ?? 0),
      voiceSparkUrl: json['voice_spark_url'] as String?,
      voiceSparkPrompt: json['voice_spark_prompt'] as String?,
      voiceSparkDuration: (json['voice_spark_duration'] as num?)?.toDouble() ?? 7.0,
      isVoiceVerified: json['is_voice_verified'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    int? age,
    String? dobVerificationPill,
    String? gender,
    String? interestedIn,
    String? maskedWhatsApp,
    String? memberSinceText,
    bool? hasVerifiedCrest,
    String? location,
    String? bio,
    String? profession,
    String? education,
    double? minAgePref,
    double? maxAgePref,
    String? avatarUrl,
    List<String>? momentPhotos,
    String? referralCode,
    int? swipesRemaining,
    int? directLettersCount,
    bool? isAdFree,
    bool? nightSlumber,
    String? subscriptionTier,
    int? rewardBalance,
    int? streakCount,
    int? boostPoints,
    int? revealTokensCount,
    int? secondsRemaining,
    String? voiceSparkUrl,
    String? voiceSparkPrompt,
    double? voiceSparkDuration,
    bool? isVoiceVerified,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      age: age ?? this.age,
      dobVerificationPill: dobVerificationPill ?? this.dobVerificationPill,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      maskedWhatsApp: maskedWhatsApp ?? this.maskedWhatsApp,
      memberSinceText: memberSinceText ?? this.memberSinceText,
      hasVerifiedCrest: hasVerifiedCrest ?? this.hasVerifiedCrest,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      education: education ?? this.education,
      minAgePref: minAgePref ?? this.minAgePref,
      maxAgePref: maxAgePref ?? this.maxAgePref,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      momentPhotos: momentPhotos ?? this.momentPhotos,
      referralCode: referralCode ?? this.referralCode,
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLettersCount: directLettersCount ?? this.directLettersCount,
      isAdFree: isAdFree ?? this.isAdFree,
      nightSlumber: nightSlumber ?? this.nightSlumber,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      rewardBalance: rewardBalance ?? this.rewardBalance,
      streakCount: streakCount ?? this.streakCount,
      boostPoints: boostPoints ?? this.boostPoints,
      revealTokensCount: revealTokensCount ?? this.revealTokensCount,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      voiceSparkUrl: voiceSparkUrl ?? this.voiceSparkUrl,
      voiceSparkPrompt: voiceSparkPrompt ?? this.voiceSparkPrompt,
      voiceSparkDuration: voiceSparkDuration ?? this.voiceSparkDuration,
      isVoiceVerified: isVoiceVerified ?? this.isVoiceVerified,
    );
  }

  List<String> get momentsUrls => momentPhotos;
  String get dateOfBirth => dobVerificationPill;
  bool get isDobVerified => true;
  String get sacredBridgeHandle => maskedWhatsApp;
  String get locationCity => location;
}

typedef UserPersonaModel = UserProfile;
