import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ads/rewarded_ad_manager.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../../../core/network/dio_client.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../rewards/data/sanctuary_billing_service.dart';
import '../../data/slumber_sensor_service.dart';

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

  final int streakCount;
  final int boostPoints;
  final int revealTokensCount;
  final int secondsRemaining;

  const GrowthHubState({
    this.userId = '',
    this.referralCode = '',
    this.swipesRemaining = 10,
    this.directLetters = 0,
    this.isAdFree = false,
    this.subscriptionTier = 'free',
    this.isSlumberActive = false,
    this.activeMatchId,
    this.activeMatchContactLink,
    this.whatsappProgress = 0,
    this.peerWhatsappProgress = 0,
    this.isWhatsappUnlocked = false,
    this.ephemeralWhatsappLink = '',
    this.streakCount = 0,
    this.boostPoints = 0,
    this.revealTokensCount = 0,
    this.secondsRemaining = 0,
  });

  bool get isStreakActive => secondsRemaining > 0 && streakCount > 0;

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
    int? streakCount,
    int? boostPoints,
    int? revealTokensCount,
    int? secondsRemaining,
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
      streakCount: streakCount ?? this.streakCount,
      boostPoints: boostPoints ?? this.boostPoints,
      revealTokensCount: revealTokensCount ?? this.revealTokensCount,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
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
      final localTokens = prefs.getInt('ur_heart_reveal_tokens') ?? state.revealTokensCount;
      final localProg = prefs.getInt('ur_heart_whatsapp_progress') ?? state.whatsappProgress;
      final localSlumber = prefs.getBool('ur_heart_night_slumber') ?? state.isSlumberActive;
      if (localSlumber) {
        SlumberSensorService.instance.startHardwareMonitoring();
      }
      state = state.copyWith(
        revealTokensCount: localTokens,
        whatsappProgress: localProg,
        isSlumberActive: localSlumber,
      );
    } catch (_) {}

    if (_profileRepo == null) return;
    try {
      final profile = await _profileRepo!.fetchMyProfile();
      final prefs = await SharedPreferences.getInstance();
      final effectiveTokens = profile.revealTokensCount;
      await prefs.setInt('ur_heart_reveal_tokens', effectiveTokens);
      await prefs.setInt('ur_heart_direct_letters', profile.directLettersCount);

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
        streakCount: profile.streakCount,
        boostPoints: profile.boostPoints,
        revealTokensCount: effectiveTokens,
        secondsRemaining: profile.secondsRemaining,
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

  Future<void> triggerMorningHarvestAuction([BuildContext? context]) async {
    final restHours = SlumberSensorService.instance.lastRestHours;
    final auction = RewardedAdManager.instance.conductProviderAuction(restHours: restHours);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mediation Auction: ${auction.winningNetwork.toUpperCase()} served a ${auction.durationSeconds}s reflection (${auction.tier.rewardLabel})',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    await triggerRewardedAd(
      adType: AdPlacementTypes.morningHarvestUnlock,
      durationSeconds: auction.durationSeconds,
      network: auction.winningNetwork,
      restHours: auction.restHours,
      context: context,
    );
  }

  Future<void> triggerRewardedAd({
    required String adType,
    String? userId,
    String targetId = 'none',
    BuildContext? context,
    int? durationSeconds,
    String? network,
    double? restHours,
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
      context: context,
      onRewardGranted: () async {
        applyReward(
          adType,
          targetId: targetId,
          durationSeconds: durationSeconds,
          restHours: restHours,
        );
        String rewardNotice = 'Verified reward applied for: $adType';
        try {
          final res = await DioClient().dio.post<dynamic>(
            '/api/v1/ads/claim-reward',
            data: {
              'ad_type': adType,
              'target_id': targetId,
              'user_id': effectiveUserId,
              'duration_seconds': durationSeconds ?? 10,
              'network': network ?? 'admob',
              'rest_hours': restHours ?? 0.0,
            },
          );
          if (res.data != null && res.data is Map<String, dynamic>) {
            final map = res.data as Map<String, dynamic>;
            if (map['message'] != null) {
              rewardNotice = map['message'].toString();
            }
            if (map['direct_letters_count'] != null) {
              final sLetters = map['direct_letters_count'] as int;
              state = state.copyWith(directLetters: sLetters);
              SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', sLetters));
            }
            if (map['swipes_remaining'] != null) {
              final sSwipes = map['swipes_remaining'] as int;
              state = state.copyWith(swipesRemaining: sSwipes);
              SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_swipes_remaining', sSwipes));
            }
            if (map['reveal_tokens_count'] != null) {
              final sTokens = map['reveal_tokens_count'] as int;
              state = state.copyWith(revealTokensCount: sTokens);
              SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_reveal_tokens', sTokens));
            }
            if (map['whatsapp_progress'] != null) {
              final sProg = map['whatsapp_progress'] as int;
              state = state.copyWith(whatsappProgress: sProg);
              SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_whatsapp_progress', sProg));
            }
          }
        } catch (e) {
          debugPrint('[GrowthHubController] Claim reward sync notice: $e');
        }
        await syncUserData();
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(rewardNotice),
              duration: const Duration(seconds: 4),
            ),
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

  void applyReward(
    String adType, {
    String targetId = 'none',
    int? durationSeconds,
    double? restHours,
  }) {
    switch (adType) {
      case 'quick_reflection':
        final nextSwipes = state.swipesRemaining + 10;
        state = state.copyWith(swipesRemaining: nextSwipes);
        SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_swipes_remaining', nextSwipes));
        break;
      case 'deep_resonance':
        final nextLetters = state.directLetters + 1;
        state = state.copyWith(directLetters: nextLetters);
        SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', nextLetters));
        break;
      case 'morning_harvest_unlock':
        final duration = durationSeconds ?? 10;
        final restHrs = restHours ?? 0.0;
        final restMult = restHrs >= 8.0 ? 2.0 : (restHrs >= 6.0 ? 1.5 : 1.0);

        if (duration <= 15) {
          final grantedSwipes = (10 * restMult).toInt();
          final nextSwipes = state.swipesRemaining + grantedSwipes;
          state = state.copyWith(swipesRemaining: nextSwipes);
          SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_swipes_remaining', nextSwipes));
        } else if (duration <= 25) {
          final nextLetters = state.directLetters + 1;
          state = state.copyWith(directLetters: nextLetters);
          SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', nextLetters));
        } else {
          final currentProg = state.whatsappProgress;
          if (currentProg >= 2) {
            final nextTokens = state.revealTokensCount + 1;
            state = state.copyWith(
              whatsappProgress: 0,
              revealTokensCount: nextTokens,
              isWhatsappUnlocked: true,
            );
            SharedPreferences.getInstance().then((p) {
              p.setInt('ur_heart_reveal_tokens', nextTokens);
              p.setInt('ur_heart_whatsapp_progress', 0);
            });
          } else {
            final nextProg = currentProg + 1;
            state = state.copyWith(whatsappProgress: nextProg);
            SharedPreferences.getInstance().then((p) {
              p.setInt('ur_heart_whatsapp_progress', nextProg);
            });
          }
        }
        break;
      case 'daily_streak_boost':
        state = state.copyWith(
          streakCount: state.streakCount + 1,
          boostPoints: state.boostPoints + 1,
          secondsRemaining: 86400,
        );
        break;
      case 'whatsapp_reveal':
      case 'sacred_bridge_reveal':
        final currentProg = state.whatsappProgress;
        if (currentProg >= 2) {
          final nextTokens = state.revealTokensCount + 1;
          state = state.copyWith(
            whatsappProgress: 0,
            revealTokensCount: nextTokens,
            isWhatsappUnlocked: true,
          );
          SharedPreferences.getInstance().then((p) {
            p.setInt('ur_heart_reveal_tokens', nextTokens);
            p.setInt('ur_heart_whatsapp_progress', 0);
          });
        } else {
          final nextProg = currentProg + 1;
          state = state.copyWith(
            whatsappProgress: nextProg,
          );
          SharedPreferences.getInstance().then((p) {
            p.setInt('ur_heart_whatsapp_progress', nextProg);
          });
        }
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

  void updateRevealTokens(int count) {
    state = state.copyWith(revealTokensCount: count);
    SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_reveal_tokens', count));
  }

  void updateDirectLetters(int count) {
    state = state.copyWith(directLetters: count);
    SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', count));
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
        final nextLetters = state.directLetters + 3;
        state = state.copyWith(directLetters: nextLetters);
        SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_direct_letters', nextLetters));
      } else if (productId == 'urheart_key_instant_contact') {
        final nextTokens = state.revealTokensCount + 1;
        state = state.copyWith(revealTokensCount: nextTokens);
        SharedPreferences.getInstance().then((p) => p.setInt('ur_heart_reveal_tokens', nextTokens));
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

  Future<void> toggleSlumberMode(bool val, [BuildContext? context]) async {
    state = state.copyWith(isSlumberActive: val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ur_heart_night_slumber', val);

      if (val) {
        SlumberSensorService.instance.startHardwareMonitoring();
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Night Sanctuary Slumber Active · Face down for mindful rest and morning harvest.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        SlumberSensorService.instance.stopHardwareMonitoring();
      }

      if (_profileRepo != null) {
        await _profileRepo!.updateNightSlumber(val);
      }
    } catch (e) {
      debugPrint('[GrowthHubController] toggleSlumberMode notice: $e');
    }
  }
}
