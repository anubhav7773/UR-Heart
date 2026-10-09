/// Settings & Governance domain model
class SanctuarySettings {
  final bool masterResonance;
  final bool discreetMode;
  final bool nightSanctuarySlumber;
  final bool isIncognito;
  final bool isPhotoVeiled;
  final String activeKeyFingerprint;
  final String userEmail;
  final String userRole;

  const SanctuarySettings({
    this.masterResonance = true,
    this.discreetMode = false,
    this.nightSanctuarySlumber = true,
    this.isIncognito = false,
    this.isPhotoVeiled = false,
    this.activeKeyFingerprint = 'CURVE25519-7F3A-89BE-4402',
    this.userEmail = '',
    this.userRole = 'user',
  });

  SanctuarySettings copyWith({
    bool? masterResonance,
    bool? discreetMode,
    bool? nightSanctuarySlumber,
    bool? isIncognito,
    bool? isPhotoVeiled,
    String? activeKeyFingerprint,
    String? userEmail,
    String? userRole,
  }) {
    return SanctuarySettings(
      masterResonance: masterResonance ?? this.masterResonance,
      discreetMode: discreetMode ?? this.discreetMode,
      nightSanctuarySlumber: nightSanctuarySlumber ?? this.nightSanctuarySlumber,
      isIncognito: isIncognito ?? this.isIncognito,
      isPhotoVeiled: isPhotoVeiled ?? this.isPhotoVeiled,
      activeKeyFingerprint: activeKeyFingerprint ?? this.activeKeyFingerprint,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
    );
  }
}

class UserPreferences {
  final bool? isIncognito;
  final bool? isPhotoVeiled;
  final bool? discreetMode;
  final bool? pushNotificationsEnabled;

  const UserPreferences({
    this.isIncognito,
    this.isPhotoVeiled,
    this.discreetMode,
    this.pushNotificationsEnabled,
  });

  Map<String, dynamic> toJson() => {
    if (isIncognito != null) 'is_incognito': isIncognito,
    if (isPhotoVeiled != null) 'is_photo_veiled': isPhotoVeiled,
    if (discreetMode != null) 'discreet_mode': discreetMode,
    if (pushNotificationsEnabled != null) 'push_notifications_enabled': pushNotificationsEnabled,
  };
}
