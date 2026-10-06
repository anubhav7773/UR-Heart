class BlindDatePartner {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String location;
  final String bio;
  final List<String> photos;
  final String? avatarUrl;
  final String? voiceSparkUrl;
  final String? voiceSparkPrompt;
  final double voiceSparkDuration;
  final bool isVoiceVerified;
  final bool isRevealed;
  final double blurRadius;

  const BlindDatePartner({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.location,
    required this.bio,
    this.photos = const [],
    this.avatarUrl,
    this.voiceSparkUrl,
    this.voiceSparkPrompt,
    this.voiceSparkDuration = 7.0,
    this.isVoiceVerified = false,
    this.isRevealed = false,
    this.blurRadius = 35.0,
  });

  factory BlindDatePartner.fromJson(Map<String, dynamic> json) {
    return BlindDatePartner(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Soul Seeker',
      age: (json['age'] as num?)?.toInt() ?? 24,
      gender: json['gender'] as String? ?? 'other',
      location: json['location'] as String? ?? 'Sanctuary',
      bio: json['bio'] as String? ?? '',
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      avatarUrl: json['avatar_url'] as String?,
      voiceSparkUrl: json['voice_spark_url'] as String?,
      voiceSparkPrompt: json['voice_spark_prompt'] as String?,
      voiceSparkDuration:
          (json['voice_spark_duration'] as num?)?.toDouble() ?? 7.0,
      isVoiceVerified: json['is_voice_verified'] as bool? ?? false,
      isRevealed: json['is_revealed'] as bool? ?? false,
      blurRadius: (json['blur_radius'] as num?)?.toDouble() ?? 35.0,
    );
  }
}

class BlindDateEligibility {
  final bool canEnter;
  final bool isStreakActive;
  final int streakCount;
  final bool hasDailyStreakPass;
  final int bonusPasses;
  final String reason; // 'ready', 'streak_inactive', 'daily_pass_exhausted'
  final String? lastBlindDateDate;

  const BlindDateEligibility({
    this.canEnter = false,
    this.isStreakActive = false,
    this.streakCount = 0,
    this.hasDailyStreakPass = false,
    this.bonusPasses = 0,
    this.reason = 'ready',
    this.lastBlindDateDate,
  });

  factory BlindDateEligibility.fromJson(Map<String, dynamic> json) {
    return BlindDateEligibility(
      canEnter: json['can_enter'] as bool? ?? false,
      isStreakActive: json['is_streak_active'] as bool? ?? false,
      streakCount: (json['streak_count'] as num?)?.toInt() ?? 0,
      hasDailyStreakPass: json['has_daily_streak_pass'] as bool? ?? false,
      bonusPasses: (json['bonus_passes'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? 'ready',
      lastBlindDateDate: json['last_blind_date_date'] as String?,
    );
  }
}

class BlindDateSessionModel {
  final String id;
  final String status; // active, revealed, passed, expired
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int remainingSeconds;
  final int extensionCount;
  final String icebreakerPrompt;
  final String myDecision; // pending, resonate, pass
  final String partnerDecision;
  final String? matchId;
  final BlindDatePartner? partner;

  const BlindDateSessionModel({
    required this.id,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.remainingSeconds = 300,
    this.extensionCount = 0,
    this.icebreakerPrompt = 'What is a quiet dream you hold close to your heart?',
    this.myDecision = 'pending',
    this.partnerDecision = 'hidden',
    this.matchId,
    this.partner,
  });

  factory BlindDateSessionModel.fromJson(Map<String, dynamic> json) {
    return BlindDateSessionModel(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 300,
      extensionCount: (json['extension_count'] as num?)?.toInt() ?? 0,
      icebreakerPrompt: json['icebreaker_prompt'] as String? ??
          'What is a quiet dream you hold close to your heart?',
      myDecision: json['my_decision'] as String? ?? 'pending',
      partnerDecision: json['partner_decision'] as String? ?? 'hidden',
      matchId: json['match_id'] as String?,
      partner: json['partner'] != null
          ? BlindDatePartner.fromJson(json['partner'] as Map<String, dynamic>)
          : null,
    );
  }

  BlindDateSessionModel copyWith({
    String? status,
    int? remainingSeconds,
    int? extensionCount,
    DateTime? expiresAt,
    String? myDecision,
    String? partnerDecision,
    String? matchId,
    BlindDatePartner? partner,
  }) {
    return BlindDateSessionModel(
      id: id,
      status: status ?? this.status,
      startedAt: startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      extensionCount: extensionCount ?? this.extensionCount,
      icebreakerPrompt: icebreakerPrompt,
      myDecision: myDecision ?? this.myDecision,
      partnerDecision: partnerDecision ?? this.partnerDecision,
      matchId: matchId ?? this.matchId,
      partner: partner ?? this.partner,
    );
  }
}

class BlindDateMessageModel {
  final String id;
  final String sessionId;
  final String senderId;
  final String ciphertext;
  final DateTime? createdAt;
  final bool isMe;

  const BlindDateMessageModel({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.ciphertext,
    this.createdAt,
    this.isMe = false,
  });

  factory BlindDateMessageModel.fromJson(Map<String, dynamic> json) {
    return BlindDateMessageModel(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isMe: json['is_me'] as bool? ?? false,
    );
  }
}
