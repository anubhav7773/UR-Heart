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
    this.swipesRemaining = 10,
    this.directLettersCount = 0,
    this.whatsappProgress = 0,
    this.peerWhatsappProgress = 0,
    this.isSlumberActive = false,
    this.referralCode = '',
    this.activeMatchId = '',
    this.activeMatchName = '',
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
