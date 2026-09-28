/// Settings & Governance domain model
class SanctuarySettings {
  final bool masterResonance;
  final bool discreetMode;
  final bool nightSanctuarySlumber;
  final bool isIncognito;
  final String activeKeyFingerprint;
  final String userEmail;
  final String userRole;

  const SanctuarySettings({
    this.masterResonance = true,
    this.discreetMode = false,
    this.nightSanctuarySlumber = true,
    this.isIncognito = false,
    this.activeKeyFingerprint = 'CURVE25519-7F3A-89BE-4402',
    this.userEmail = '',
    this.userRole = 'user',
  });

  SanctuarySettings copyWith({
    bool? masterResonance,
    bool? discreetMode,
    bool? nightSanctuarySlumber,
    bool? isIncognito,
    String? activeKeyFingerprint,
    String? userEmail,
    String? userRole,
  }) {
    return SanctuarySettings(
      masterResonance: masterResonance ?? this.masterResonance,
      discreetMode: discreetMode ?? this.discreetMode,
      nightSanctuarySlumber: nightSanctuarySlumber ?? this.nightSanctuarySlumber,
      isIncognito: isIncognito ?? this.isIncognito,
      activeKeyFingerprint: activeKeyFingerprint ?? this.activeKeyFingerprint,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
    );
  }
}

