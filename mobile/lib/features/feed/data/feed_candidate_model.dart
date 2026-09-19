class CandidatePhotoModel {
  final int slotIndex;
  final String photoUrl;
  final String blurHash;

  CandidatePhotoModel({
    required this.slotIndex,
    required this.photoUrl,
    required this.blurHash,
  });

  factory CandidatePhotoModel.fromJson(Map<String, dynamic> json) {
    return CandidatePhotoModel(
      slotIndex: json['slot_index'] as int? ?? 1,
      photoUrl: (json['photo_url'] ?? json['photo_storage_path'] ?? '') as String,
      blurHash: (json['blur_hash'] ?? 'LEHLh[WB2yk8pyoJadR*.7kCMdnj') as String,
    );
  }
}

class FeedCandidateModel {
  final String userId;
  final String fullName;
  final String city;
  final String? detectedLocality;
  final int? distanceKm;
  final String gender;
  final String bio;
  final int streakCount;
  final List<CandidatePhotoModel> photos;

  FeedCandidateModel({
    required this.userId,
    required this.fullName,
    required this.city,
    this.detectedLocality,
    this.distanceKm,
    required this.gender,
    required this.bio,
    required this.streakCount,
    required this.photos,
  });

  factory FeedCandidateModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List? ?? [];
    return FeedCandidateModel(
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Anonymous').toString(),
      city: (json['city'] ?? '').toString(),
      detectedLocality: json['detected_locality'] as String?,
      distanceKm: json['distance_km'] as int?,
      gender: (json['gender'] ?? 'other').toString(),
      bio: (json['bio'] ?? '').toString(),
      streakCount: json['streak_count'] as int? ?? 0,
      photos: rawPhotos
          .map((p) => CandidatePhotoModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  String get id => userId;
  String get primaryPhotoUrl => photos.isNotEmpty ? photos.first.photoUrl : '';
}
