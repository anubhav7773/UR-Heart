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
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
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
      hasVerifiedCrest: json['kyc_status'] as bool? ?? true,
      location: json['location_name'] as String? ?? json['location'] as String? ?? 'Ayodhya, UP',
      bio: json['bio'] as String? ?? '',
      profession: json['profession'] as String? ?? '',
      education: json['education'] as String? ?? '',
      minAgePref: (json['preferred_age_min'] as num?)?.toDouble() ?? 18.0,
      maxAgePref: (json['preferred_age_max'] as num?)?.toDouble() ?? 35.0,
      avatarUrl: json['avatar_url'] as String? ?? (json['photos'] is List && (json['photos'] as List).isNotEmpty ? (json['photos'] as List).first as String : ''),
      momentPhotos: List<String>.from(json['photos'] as List? ?? json['moment_photos'] as List? ?? []),
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
    );
  }

  List<String> get momentsUrls => momentPhotos;
  String get dateOfBirth => dobVerificationPill;
  bool get isDobVerified => true;
  String get sacredBridgeHandle => maskedWhatsApp;
  String get locationCity => location;
}

typedef UserPersonaModel = UserProfile;
