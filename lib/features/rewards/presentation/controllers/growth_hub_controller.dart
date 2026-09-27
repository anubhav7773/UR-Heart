import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/billing/sanctuary_billing_service.dart';

class GrowthHubState {
  final String userId;
  final int swipesRemaining;
  final int directLetters;
  final bool isAdFree;
  final String subscriptionTier;
  final bool isSlumberActive;
  final String referralCode;
  final String? activeMatchId;
  final int whatsappProgress;
  final int peerWhatsappProgress;
  final bool isWhatsappUnlocked;
  final String ephemeralWhatsappLink;

  const GrowthHubState({
    this.userId = 'user-sanctuary',
    this.swipesRemaining = 25,
    this.directLetters = 1,
    this.isAdFree = false,
    this.subscriptionTier = 'free',
    this.isSlumberActive = false,
    this.referralCode = 'SOUL-7842',
    this.activeMatchId,
    this.whatsappProgress = 1,
    this.peerWhatsappProgress = 1,
    this.isWhatsappUnlocked = false,
    this.ephemeralWhatsappLink = 'https://wa.me/919876543210',
  });

  GrowthHubState copyWith({
    String? userId,
    int? swipesRemaining,
    int? directLetters,
    bool? isAdFree,
    String? subscriptionTier,
    bool? isSlumberActive,
    String? referralCode,
    String? activeMatchId,
    int? whatsappProgress,
    int? peerWhatsappProgress,
    bool? isWhatsappUnlocked,
    String? ephemeralWhatsappLink,
  }) {
    return GrowthHubState(
      userId: userId ?? this.userId,
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLetters: directLetters ?? this.directLetters,
      isAdFree: isAdFree ?? this.isAdFree,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isSlumberActive: isSlumberActive ?? this.isSlumberActive,
      referralCode: referralCode ?? this.referralCode,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      whatsappProgress: whatsappProgress ?? this.whatsappProgress,
      peerWhatsappProgress: peerWhatsappProgress ?? this.peerWhatsappProgress,
      isWhatsappUnlocked: isWhatsappUnlocked ?? this.isWhatsappUnlocked,
      ephemeralWhatsappLink: ephemeralWhatsappLink ?? this.ephemeralWhatsappLink,
    );
  }
}

final growthHubControllerProvider =
    StateNotifierProvider<GrowthHubController, GrowthHubState>((ref) {
  return GrowthHubController();
});

/// Controller managing balance synchronization, ad dispatches & IAP purchases (< 210 lines)
class GrowthHubController extends StateNotifier<GrowthHubState> {
  final SanctuaryBillingService _billing = SanctuaryBillingService.instance;
  final RewardedAdManager _adManager = RewardedAdManager.instance;

  GrowthHubController([GrowthHubState? initial])
      : super(initial ?? const GrowthHubState()) {
    syncBalances();
  }

  void syncBalances({String? userId}) {
    state = state.copyWith(
      userId: userId ?? state.userId,
      isAdFree: _billing.isAdFree,
      subscriptionTier: _billing.activeTier,
    );
  }

  Future<void> triggerRewardedAd({
    required String adType,
    String? userId,
    String targetId = 'none',
    BuildContext? context,
  }) async {
    // Ad-Free Sovereign Entitlement: Suppress ads if subscriber
    if (state.isAdFree || state.subscriptionTier != 'free') {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sovereign Entitlement active: Zero ads required.')),
        );
      }
      return;
    }

    final effectiveUserId = userId ?? state.userId;
    await _adManager.showRewardedAd(
      userId: effectiveUserId,
      adType: adType,
      targetId: targetId,
      onRewardGranted: () {
        applyReward(adType, targetId: targetId);
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verified reward applied for: $adType')),
          );
        }
      },
      onPlaybackFailed: (error) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );
  }

  void applyReward(String adType, {String targetId = 'none'}) {
    switch (adType) {
      case AdPlacementTypes.quickReflection:
        state = state.copyWith(swipesRemaining: state.swipesRemaining + 10);
        break;
      case AdPlacementTypes.deepResonance:
        state = state.copyWith(directLetters: state.directLetters + 1);
        break;
      case AdPlacementTypes.morningHarvestUnlock:
        state = state.copyWith(
          swipesRemaining: state.swipesRemaining + 20,
          directLetters: state.directLetters + 2,
        );
        break;
      case AdPlacementTypes.whatsappReveal:
      case 'sacred_bridge_reveal':
        final nextProgress = (state.whatsappProgress + 1).clamp(1, 3);
        final isUnlocked = nextProgress >= 3 && state.peerWhatsappProgress >= 3;
        state = state.copyWith(
          whatsappProgress: nextProgress,
          isWhatsappUnlocked: isUnlocked,
        );
        break;
    }
  }

  void toggleSlumberMode(bool val) {
    state = state.copyWith(isSlumberActive: val);
  }

  Future<void> purchasePackage(String productId, [BuildContext? context]) async {
    final success = await _billing.purchasePackage(productId);
    if (success) {
      syncBalances();
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlocked ${productId.replaceAll('_', ' ')}')),
        );
      }
    }
  }

  Future<void> purchaseMicroPack(String productId) async {
    final success = await _billing.purchaseMicroPack(productId);
    if (success) {
      if (productId == 'urheart_pack_direct_letters') {
        state = state.copyWith(directLetters: state.directLetters + 3);
      } else if (productId == 'urheart_key_instant_contact') {
        state = state.copyWith(isWhatsappUnlocked: true);
      }
    }
  }

  Future<void> restorePurchases([BuildContext? context]) async {
    await _billing.restorePurchases();
    syncBalances();
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases successfully restored from Google Play.')),
      );
    }
  }

  void advancePeerWhatsappProgress(int progress) {
    final nextPeer = progress.clamp(1, 3);
    final isUnlocked = state.whatsappProgress >= 3 && nextPeer >= 3;
    state = state.copyWith(
      peerWhatsappProgress: nextPeer,
      isWhatsappUnlocked: isUnlocked,
    );
  }
}
