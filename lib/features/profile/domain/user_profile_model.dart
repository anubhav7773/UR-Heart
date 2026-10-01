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
  });

  bool get isStreakActive => secondsRemaining > 0 && streakCount > 0;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawAvatar = (json['avatar_url'] as String? ?? '').trim();
    final rawPhotos = (json['photos'] is List
            ? (json['photos'] as List<dynamic>)
            : (json['moment_photos'] is List
                ? (json['moment_photos'] as List<dynamic>)
                : const <dynamic>[]))
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

    return UserProfile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Seeker',
      email: json['email'] as String? ?? '',
      age: json['age'] as int? ?? 24,
      dobVerificationPill: json['dob'] as String? ?? 'Verified via DigiLocker',
      gender: json['gender'] as String? ?? 'Seeker',
      interestedIn: json['interested_in'] as String? ?? 'Everyone',
      maskedWhatsApp: json['contact_bridge_masked'] as String? ?? '+91 **** ****',
      memberSinceText: 'Member of Sanctuary',
      hasVerifiedCrest: json['kyc_status'] as bool? ??
          (json['is_kyc_verified'] as bool? ??
              (json['is_kyc'] as bool? ?? false)),
      location: json['location_name'] as String? ?? json['location'] as String? ?? 'Ayodhya, UP',
      bio: json['bio'] as String? ?? '',
      profession: json['profession'] as String? ?? '',
      education: json['education'] as String? ?? '',
      minAgePref: (json['preferred_age_min'] as num?)?.toDouble() ?? 18.0,
      maxAgePref: (json['preferred_age_max'] as num?)?.toDouble() ?? 35.0,
      avatarUrl: resolvedAvatar,
      momentPhotos: resolvedMoments,
      referralCode: json['referral_code'] as String? ?? '',
      swipesRemaining: json['swipes_remaining'] as int? ?? 10,
      directLettersCount: json['direct_letters_count'] as int? ?? 0,
      isAdFree: json['is_ad_free'] as bool? ?? false,
      nightSlumber: json['night_slumber'] as bool? ?? false,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      rewardBalance: json['reward_balance'] as int? ?? 0,
      streakCount: json['streak_count'] as int? ?? 0,
      boostPoints: json['boost_points'] as int? ?? 0,
      revealTokensCount: json['reveal_tokens_count'] as int? ?? 0,
      secondsRemaining: (json['streak_info'] is Map && json['streak_info']['seconds_remaining'] != null)
          ? (json['streak_info']['seconds_remaining'] as int)
          : (json['seconds_remaining'] as int? ?? 0),
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
    );
  }

  List<String> get momentsUrls => momentPhotos;
  String get dateOfBirth => dobVerificationPill;
  bool get isDobVerified => true;
  String get sacredBridgeHandle => maskedWhatsApp;
  String get locationCity => location;
}

typedef UserPersonaModel = UserProfile;
