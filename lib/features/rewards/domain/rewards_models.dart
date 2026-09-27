/// Immutable state container for Screen 10 Growth PRO & Rewards Hub
class RewardHubState {
  final int swipesRemaining;
  final int directLettersCount;
  final int whatsappProgress;
  final int peerWhatsappProgress;
  final bool isSlumberActive;
  final String referralCode;
  final String activeMatchId;
  final String activeMatchName;
  final String? ephemeralWhatsappLink;

  const RewardHubState({
    this.swipesRemaining = 25,
    this.directLettersCount = 1,
    this.whatsappProgress = 2,
    this.peerWhatsappProgress = 2,
    this.isSlumberActive = false,
    this.referralCode = 'SANCTUARY-09',
    this.activeMatchId = 'match-sacred-enclave-01',
    this.activeMatchName = 'Ananya',
    this.ephemeralWhatsappLink,
  });

  bool get isWhatsappUnlocked =>
      whatsappProgress >= 3 && peerWhatsappProgress >= 3;

  RewardHubState copyWith({
    int? swipesRemaining,
    int? directLettersCount,
    int? whatsappProgress,
    int? peerWhatsappProgress,
    bool? isSlumberActive,
    String? referralCode,
    String? activeMatchId,
    String? activeMatchName,
    String? ephemeralWhatsappLink,
  }) {
    return RewardHubState(
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLettersCount: directLettersCount ?? this.directLettersCount,
      whatsappProgress: whatsappProgress ?? this.whatsappProgress,
      peerWhatsappProgress: peerWhatsappProgress ?? this.peerWhatsappProgress,
      isSlumberActive: isSlumberActive ?? this.isSlumberActive,
      referralCode: referralCode ?? this.referralCode,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      activeMatchName: activeMatchName ?? this.activeMatchName,
      ephemeralWhatsappLink: ephemeralWhatsappLink ?? this.ephemeralWhatsappLink,
    );
  }
}
