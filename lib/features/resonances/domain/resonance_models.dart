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
  });

  factory IncomingLikeProfile.fromJson(Map<String, dynamic> json) {
    return IncomingLikeProfile(
      id: json['id'] as String? ?? 'like_${DateTime.now().millisecondsSinceEpoch}',
      senderId: json['sender_id'] as String? ?? json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? 'Seeker',
      age: json['age'] as int? ?? 24,
      photoUrl: json['photo_url'] as String? ?? (json['photos'] is List && (json['photos'] as List).isNotEmpty ? (json['photos'] as List).first as String : ''),
      blurHash: json['blur_hash'] as String? ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
      relativeTime: json['relative_time'] as String? ?? 'recently',
      sharedInterest: json['shared_interest'] as String? ?? 'Shared Values',
      matchScore: json['match_score'] as int? ?? 90,
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
  });

  factory MutualConnection.fromJson(Map<String, dynamic> json) {
    return MutualConnection(
      id: json['id'] as String? ?? 'conn_${DateTime.now().millisecondsSinceEpoch}',
      matchId: json['match_id'] as String? ?? '',
      partnerId: json['partner_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Soul Connection',
      age: json['age'] as int? ?? 25,
      photoUrl: json['photo_url'] as String? ?? '',
      blurHash: json['blur_hash'] as String? ?? 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
      matchedTime: json['matched_time'] as String? ?? 'Today',
      lastSnippet: json['last_snippet'] as String? ?? 'Connection established.',
      hasUnreadMessages: json['has_unread'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? true,
    );
  }
}
