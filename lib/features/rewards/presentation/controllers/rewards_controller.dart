import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../domain/rewards_models.dart';

/// Riverpod StateNotifier managing the user's reward resources and Enclave progress
class RewardsController extends StateNotifier<RewardHubState> {
  static const String keySwipes = 'ur_heart_swipes_remaining';
  static const String keyLetters = 'ur_heart_direct_letters';
  static const String keyWaProgress = 'ur_heart_wa_progress';
  static const String keyPeerWaProgress = 'ur_heart_peer_wa_progress';
  static const String keySlumber = 'ur_heart_slumber_active';

  RewardsController([RewardHubState? initialState])
      : super(initialState ?? const RewardHubState()) {
    if (initialState == null) {
      loadSavedState();
    }
  }

  Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final swipes = prefs.getInt(keySwipes) ?? 25;
    final letters = prefs.getInt(keyLetters) ?? 1;
    final wa = prefs.getInt(keyWaProgress) ?? 2;
    final peerWa = prefs.getInt(keyPeerWaProgress) ?? 2;
    final slumber = prefs.getBool(keySlumber) ?? false;

    state = state.copyWith(
      swipesRemaining: swipes,
      directLettersCount: letters,
      whatsappProgress: wa,
      peerWhatsappProgress: peerWa,
      isSlumberActive: slumber,
      ephemeralWhatsappLink: (wa >= 3 && peerWa >= 3)
          ? 'https://wa.me/919876543210?text=Sacred%20Enclave%20Unlocked'
          : null,
    );
  }

  Future<void> applyReward(String adType, {String targetId = 'none'}) async {
    int updatedSwipes = state.swipesRemaining;
    int updatedLetters = state.directLettersCount;
    int updatedWa = state.whatsappProgress;
    String? waLink = state.ephemeralWhatsappLink;

    if (adType == AdPlacementTypes.quickReflection) {
      updatedSwipes += 10;
    } else if (adType == AdPlacementTypes.deepResonance) {
      updatedLetters += 1;
    } else if (adType == AdPlacementTypes.morningHarvestUnlock) {
      updatedSwipes += 20;
      updatedLetters += 2;
    } else if (adType == AdPlacementTypes.whatsappReveal) {
      if (updatedWa < 3) {
        updatedWa += 1;
      }
      if (updatedWa >= 3 && state.peerWhatsappProgress >= 3) {
        waLink = 'https://wa.me/919876543210?text=Sacred%20Enclave%20Unlocked';
      }
    }

    state = state.copyWith(
      swipesRemaining: updatedSwipes,
      directLettersCount: updatedLetters,
      whatsappProgress: updatedWa,
      ephemeralWhatsappLink: waLink,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySwipes, updatedSwipes);
    await prefs.setInt(keyLetters, updatedLetters);
    await prefs.setInt(keyWaProgress, updatedWa);
  }

  Future<void> setSlumberMode(bool active) async {
    state = state.copyWith(isSlumberActive: active);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySlumber, active);
  }

  Future<void> advancePeerWhatsappProgress(int progress) async {
    final clamped = progress.clamp(0, 3);
    final isBothUnlocked = state.whatsappProgress >= 3 && clamped >= 3;
    state = state.copyWith(
      peerWhatsappProgress: clamped,
      ephemeralWhatsappLink: isBothUnlocked
          ? 'https://wa.me/919876543210?text=Sacred%20Enclave%20Unlocked'
          : null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyPeerWaProgress, clamped);
  }
}

final rewardsControllerProvider =
    StateNotifierProvider<RewardsController, RewardHubState>((ref) {
  return RewardsController();
});
