class IncomingLikeProfile {
  final String id;
  final String senderId;
  final String fullName;
  final int age;
  final String photoUrl;
  final String blurHash;
  final String relativeTime;
  final String sharedInterest;
  final int matchScore;
  final String swipeType;
  final bool isDirectLetter;
  final String categoryTag;
  final String? letterSnippet;
  final String bio;
  final String location;
  final bool isVerified;

  const IncomingLikeProfile({
    required this.id,
    required this.senderId,
    required this.fullName,
    required this.age,
    required this.photoUrl,
    required this.blurHash,
    required this.relativeTime,
    required this.sharedInterest,
    this.matchScore = 92,
    this.swipeType = 'like',
    this.isDirectLetter = false,
    this.categoryTag = 'Liked You',
    this.letterSnippet,
    this.bio = '',
    this.location = '',
    this.isVerified = false,
  });

  factory IncomingLikeProfile.fromJson(Map<String, dynamic> json) {
    final isDirect = json['is_direct_letter'] as bool? ??
        (json['swipe_type']?.toString().toLowerCase() == 'direct');
    final rawAge = json['age'];
    final parsedAge = rawAge is num ? rawAge.toInt() : (int.tryParse(rawAge?.toString() ?? '') ?? 24);
    final rawScore = json['match_score'];
    final parsedScore = rawScore is num ? rawScore.toInt() : (int.tryParse(rawScore?.toString() ?? '') ?? 90);

    return IncomingLikeProfile(
      id: json['id']?.toString() ?? 'like_${DateTime.now().millisecondsSinceEpoch}',
      senderId: json['sender_id']?.toString() ??
          json['user_id']?.toString() ??
          json['actor_id']?.toString() ??
          '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Seeker',
      age: parsedAge,
      photoUrl: json['photo_url']?.toString() ??
          json['avatar_url']?.toString() ??
          (json['photos'] is List && (json['photos'] as List).isNotEmpty
              ? (json['photos'] as List).first.toString()
              : ''),
      blurHash: json['blur_hash']?.toString() ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
      relativeTime: json['relative_time']?.toString() ?? 'Recently',
      sharedInterest: json['shared_interest']?.toString() ?? 'Shared Values',
      matchScore: parsedScore,
      swipeType: json['swipe_type']?.toString().toLowerCase() ?? (isDirect ? 'direct' : 'like'),
      isDirectLetter: isDirect,
      categoryTag: json['category_tag']?.toString() ?? (isDirect ? 'Direct Letter' : 'Liked You'),
      letterSnippet: json['letter_snippet']?.toString(),
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? json['city']?.toString() ?? '',
      isVerified: json['is_verified'] == true || json['kyc_status'] == true,
    );
  }
}

typedef IncomingLike = IncomingLikeProfile;

class MutualConnection {
  final String id;
  final String matchId;
  final String partnerId;
  final String fullName;
  final int age;
  final String photoUrl;
  final String blurHash;
  final String matchedTime;
  final String lastSnippet;
  final bool hasUnreadMessages;
  final bool isOnline;
  final String categoryTag;
  final bool isDirectLetter;
  final bool isVerified;
  final String bio;
  final String location;
  final String gender;
  final List<String> interests;

  const MutualConnection({
    required this.id,
    required this.matchId,
    required this.partnerId,
    required this.fullName,
    required this.age,
    required this.photoUrl,
    required this.blurHash,
    required this.matchedTime,
    required this.lastSnippet,
    this.hasUnreadMessages = false,
    this.isOnline = true,
    this.categoryTag = 'Mutual Resonance',
    this.isDirectLetter = false,
    this.isVerified = false,
    this.bio = '',
    this.location = '',
    this.gender = '',
    this.interests = const [],
  });

  factory MutualConnection.fromJson(Map<String, dynamic> json) {
    final isDirect = json['is_direct_letter'] as bool? ??
        (json['category_tag']?.toString().toLowerCase().contains('direct') ?? false);
    final rawAge = json['age'];
    final parsedAge = rawAge is num ? rawAge.toInt() : (int.tryParse(rawAge?.toString() ?? '') ?? 25);

    return MutualConnection(
      id: json['id']?.toString() ?? 'conn_${DateTime.now().millisecondsSinceEpoch}',
      matchId: json['match_id']?.toString() ?? json['id']?.toString() ?? '',
      partnerId: json['partner_id']?.toString() ?? json['recipient_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Soul Connection',
      age: parsedAge,
      photoUrl: json['photo_url']?.toString() ??
          json['avatar_url']?.toString() ??
          json['recipient_avatar_url']?.toString() ??
          '',
      blurHash: json['blur_hash']?.toString() ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
      matchedTime: json['matched_time']?.toString() ?? 'Today',
      lastSnippet: json['last_snippet']?.toString() ?? 'Connection established.',
      hasUnreadMessages: json['has_unread'] == true,
      isOnline: json['is_online'] != false,
      categoryTag: json['category_tag']?.toString() ?? (isDirect ? 'Direct Letter' : 'Mutual Resonance'),
      isDirectLetter: isDirect,
      isVerified: json['is_verified'] == true || json['kyc_status'] == true,
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
