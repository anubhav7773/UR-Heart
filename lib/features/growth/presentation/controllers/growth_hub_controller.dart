import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/network/dio_client.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../rewards/data/sanctuary_billing_service.dart';

class GrowthHubState {
  final String userId;
  final String referralCode;
  final int swipesRemaining;
  final int directLetters;
  final bool isAdFree;
  final String subscriptionTier;
  final bool isSlumberActive;
  final String? activeMatchId;
  final String? activeMatchContactLink; // Resolved only at Stage 3
  final int whatsappProgress;
  final int peerWhatsappProgress;
  final bool isWhatsappUnlocked;
  final String ephemeralWhatsappLink;

  const GrowthHubState({
    this.userId = '',
    this.referralCode = '',
    this.swipesRemaining = 25,
    this.directLetters = 1,
    this.isAdFree = false,
    this.subscriptionTier = 'free',
    this.isSlumberActive = false,
    this.activeMatchId,
    this.activeMatchContactLink,
    this.whatsappProgress = 1,
    this.peerWhatsappProgress = 1,
    this.isWhatsappUnlocked = false,
    this.ephemeralWhatsappLink = '',
  });

  GrowthHubState copyWith({
    String? userId,
    String? referralCode,
    int? swipesRemaining,
    int? directLetters,
    bool? isAdFree,
    String? subscriptionTier,
    bool? isSlumberActive,
    String? activeMatchId,
    String? activeMatchContactLink,
    int? whatsappProgress,
    int? peerWhatsappProgress,
    bool? isWhatsappUnlocked,
    String? ephemeralWhatsappLink,
  }) {
    return GrowthHubState(
      userId: userId ?? this.userId,
      referralCode: referralCode ?? this.referralCode,
      swipesRemaining: swipesRemaining ?? this.swipesRemaining,
      directLetters: directLetters ?? this.directLetters,
      isAdFree: isAdFree ?? this.isAdFree,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isSlumberActive: isSlumberActive ?? this.isSlumberActive,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      activeMatchContactLink: activeMatchContactLink ?? this.activeMatchContactLink,
      whatsappProgress: whatsappProgress ?? this.whatsappProgress,
      peerWhatsappProgress: peerWhatsappProgress ?? this.peerWhatsappProgress,
      isWhatsappUnlocked: isWhatsappUnlocked ?? this.isWhatsappUnlocked,
      ephemeralWhatsappLink: ephemeralWhatsappLink ?? this.ephemeralWhatsappLink,
    );
  }
}

final growthHubControllerProvider =
    StateNotifierProvider<GrowthHubController, GrowthHubState>((ref) {
  final profileRepo = ref.read(profileRepositoryProvider);
  final billing = ref.read(sanctuaryBillingServiceProvider);
  return GrowthHubController(profileRepo, billing);
});

class GrowthHubController extends StateNotifier<GrowthHubState> {
  final ProfileRepository? _profileRepo;
  final SanctuaryBillingService? _billing;

  GrowthHubController([dynamic repoOrState, this._billing])
      : _profileRepo = repoOrState is ProfileRepository ? repoOrState : null,
        super(repoOrState is GrowthHubState
            ? repoOrState
            : GrowthHubState(
                isAdFree: _billing?.isAdFree ?? SanctuaryBillingService.instance.isAdFree,
                subscriptionTier: _billing?.activeTier ?? SanctuaryBillingService.instance.activeTier,
              )) {
    syncBalances();
  }

  /// DUM-11 FIX: Binds directly to authenticated database user profile
  Future<void> syncUserData() async {
    // 1. Instant local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('profile_referral_code') ?? prefs.getString('ur_heart_user_referral_code');
      if (cached != null && cached.isNotEmpty && state.referralCode.isEmpty) {
        state = state.copyWith(referralCode: cached);
      }
    } catch (_) {}

    if (_profileRepo == null) return;
    try {
      final profile = await _profileRepo!.fetchMyProfile();
      state = state.copyWith(
        userId: profile.id,
        referralCode: profile.referralCode,
        swipesRemaining: profile.swipesRemaining,
        directLetters: profile.directLettersCount,
        isAdFree: profile.isAdFree || (_billing?.isAdFree ?? SanctuaryBillingService.instance.isAdFree),
        subscriptionTier: profile.subscriptionTier != 'free'
            ? profile.subscriptionTier
            : (_billing?.activeTier ?? SanctuaryBillingService.instance.activeTier),
        isSlumberActive: profile.nightSlumber,
      );
    } catch (_) {}
  }

  /// Submits friend's referral code to backend for 20 reflections bonus
  Future<String> redeemReferralCode(String code) async {
    if (_profileRepo == null) {
      throw Exception('Sanctuary profile service unavailable');
    }
    final res = await _profileRepo!.redeemReferralCode(code);
    await syncUserData();
    return res['message']?.toString() ?? 'Referral code redeemed successfully!';
  }

  void syncBalances({String? userId}) {
    final billing = _billing ?? SanctuaryBillingService.instance;
    state = state.copyWith(
      userId: userId ?? (state.userId.isNotEmpty ? state.userId : null),
      isAdFree: billing.isAdFree,
      subscriptionTier: billing.activeTier,
    );
    if (_profileRepo != null) {
      syncUserData();
    }
  }

  /// DUM-12 FIX: Resolves contact bridge URL strictly at Stage 3 mutual unlock
  void resolveMutualContactLink(String platform, String rawHandle, int currentStage) {
    if (currentStage < 3) {
      state = state.copyWith(
        activeMatchContactLink: null,
        ephemeralWhatsappLink: '',
        isWhatsappUnlocked: false,
      );
      return;
    }

    final handle = rawHandle.replaceAll('@', '').trim();
    String link = '';

    if (platform == 'whatsapp') {
      final phone = handle.replaceAll(RegExp(r'[^0-9]'), '');
      link = 'https://wa.me/$phone';
    } else if (platform == 'instagram') {
      link = 'https://instagram.com/$handle';
    } else if (platform == 'telegram') {
      link = 'https://t.me/$handle';
    } else if (platform == 'signal') {
      link = 'https://signal.me/#p/$handle';
    }

    state = state.copyWith(
      activeMatchContactLink: link,
      ephemeralWhatsappLink: link,
      isWhatsappUnlocked: true,
    );
  }

  Future<void> triggerRewardedAd({
    required String adType,
    String? userId,
    String targetId = 'none',
    BuildContext? context,
  }) async {
    if (state.isAdFree || state.subscriptionTier != 'free') {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sovereign Entitlement active: Zero ads required.')),
        );
      }
      return;
    }

    final effectiveUserId = (userId != null && userId.isNotEmpty) ? userId : state.userId;
    await RewardedAdManager.instance.showRewardedAd(
      userId: effectiveUserId,
      adType: adType,
      targetId: targetId,
      onRewardGranted: () async {
        applyReward(adType, targetId: targetId);
        try {
          await DioClient().dio.post<dynamic>(
            '/api/v1/ads/claim-reward',
            data: {
              'ad_type': adType,
              'target_id': targetId,
              'user_id': effectiveUserId,
            },
          );
        } catch (e) {
          debugPrint('[GrowthHubController] Claim reward sync notice: $e');
        }
        await syncUserData();
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
      case 'quick_reflection':
        state = state.copyWith(swipesRemaining: state.swipesRemaining + 10);
        break;
      case 'deep_resonance':
        state = state.copyWith(directLetters: state.directLetters + 1);
        break;
      case 'morning_harvest_unlock':
        state = state.copyWith(
          swipesRemaining: state.swipesRemaining + 20,
          directLetters: state.directLetters + 2,
        );
        break;
      case 'whatsapp_reveal':
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

  void advancePeerWhatsappProgress(int progress) {
    final nextPeer = progress.clamp(1, 3);
    final isUnlocked = state.whatsappProgress >= 3 && nextPeer >= 3;
    state = state.copyWith(
      peerWhatsappProgress: nextPeer,
      isWhatsappUnlocked: isUnlocked,
    );
  }

  Future<void> purchasePackage(String productId, [BuildContext? context]) async {
    try {
      if (_billing != null) {
        await _billing!.purchasePackage(productId);
      } else {
        await SanctuaryBillingService.instance.purchasePackage(productId);
      }
      await syncUserData();
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlocked ${productId.replaceAll('_', ' ')}')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to connect to Google Play: $e')),
        );
      }
    }
  }

  Future<void> purchaseMicroPack(String productId) async {
    try {
      if (_billing != null) {
        await _billing!.purchaseMicroPack(productId);
      } else {
        await SanctuaryBillingService.instance.purchaseMicroPack(productId);
      }
      if (productId == 'urheart_pack_direct_letters') {
        state = state.copyWith(directLetters: state.directLetters + 3);
      } else if (productId == 'urheart_key_instant_contact') {
        state = state.copyWith(isWhatsappUnlocked: true);
      }
    } catch (_) {}
  }

  /// Launches official Web Sanctuary Store with pre-filled user parameters
  Future<void> openWebStore([String? productId, BuildContext? context]) async {
    final query = <String, String>{};
    if (productId != null && productId.isNotEmpty) {
      query['product'] = productId;
    }
    if (state.userId.isNotEmpty) {
      query['user_id'] = state.userId;
    }
    if (state.referralCode.isNotEmpty) {
      query['ref'] = state.referralCode;
    }

    final uri = Uri.https('urheart.asiverticals.me', '/store', query.isNotEmpty ? query : null);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open https://urheart.asiverticals.me/store in browser.')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open web store: $e')),
        );
      }
    }
  }

  Future<void> restorePurchases([BuildContext? context]) async {
    try {
      if (_billing != null) {
        await _billing!.restorePurchases();
      } else {
        await SanctuaryBillingService.instance.restorePurchases();
      }
      await syncUserData();
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases successfully restored from Google Play.')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore purchases: $e')),
        );
      }
    }
  }

  void toggleSlumberMode(bool val) {
    state = state.copyWith(isSlumberActive: val);
  }
}
