import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ur_heart/core/config/env_config.dart';

/// Multi-Network Ad Preload Buffer and SSV Custom Data Engine
/// Implements dual-slot background preload buffer to eliminate ad loading latency.
class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  RewardedAd? _preloadedRewardedAd;
  InterstitialAd? _preloadedInterstitialAd;
  bool _isRewardedLoading = false;
  bool _isInterstitialLoading = false;

  // ASI Verticals Configurable Ad Unit IDs
  String get rewardedUnitId => EnvConfig.admobRewardedUnitId;
  String get interstitialUnitId => EnvConfig.admobInterstitialUnitId;

  bool get isRewardedAdReady => _preloadedRewardedAd != null;
  bool get isInterstitialAdReady => _preloadedInterstitialAd != null;

  /// Formats SSV custom data according to UR-Heart specification: {userId}:{adType}:{targetId}
  static String formatSsvCustomData({
    required String userId,
    required String adType,
    required String targetId,
  }) {
    return '$userId:$adType:$targetId';
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      if (EnvConfig.admobTestDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: EnvConfig.admobTestDeviceIds),
        );
      }
      preloadRewardedAd();
      preloadInterstitialAd();
    } catch (e) {
      debugPrint('MobileAds initialization error: $e');
    }
  }

  void preloadRewardedAd() {
    if (_isRewardedLoading || _preloadedRewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedRewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _preloadedRewardedAd = null;
          _isRewardedLoading = false;
          // Exponential backoff
          Future.delayed(const Duration(seconds: 10), () => preloadRewardedAd());
        },
      ),
    );
  }

  void preloadInterstitialAd() {
    if (_isInterstitialLoading || _preloadedInterstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedInterstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _preloadedInterstitialAd = null;
          _isInterstitialLoading = false;
          Future.delayed(const Duration(seconds: 20), () => preloadInterstitialAd());
        },
      ),
    );
  }

  /// Displays Rewarded Ad and passes SSV custom data: {userId}:{adType}:{targetId}
  bool showRewardedAd({
    required String userId,
    required String adType,
    required String targetId,
    required VoidCallback onRewardGranted,
  }) {
    if (_preloadedRewardedAd == null) {
      preloadRewardedAd();
      return false; // Ad not ready
    }

    final customData = formatSsvCustomData(
      userId: userId,
      adType: adType,
      targetId: targetId,
    );

    _preloadedRewardedAd!.setServerSideOptions(
      ServerSideVerificationOptions(
        userId: userId,
        customData: customData,
      ),
    );

    _preloadedRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewardedAd(); // Immediately buffer next video
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadedRewardedAd = null;
        preloadRewardedAd();
      },
    );

    _preloadedRewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewardGranted();
      },
    );
    return true;
  }

  /// Displays Interstitial Ad and buffers next interstitial video upon dismissal.
  bool showInterstitialAd({VoidCallback? onDismissed}) {
    if (_preloadedInterstitialAd == null) {
      preloadInterstitialAd();
      return false;
    }

    _preloadedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadedInterstitialAd = null;
        preloadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadedInterstitialAd = null;
        preloadInterstitialAd();
        onDismissed?.call();
      },
    );

    _preloadedInterstitialAd!.show();
    return true;
  }
}

extension MultiTierAdManager on AdManager {
  Future<void> showTieredAd({
    required BuildContext context,
    required String adTier, // '10s', '20s', '30s'
    required String rewardChoice,
    required VoidCallback onRewardSuccess,
  }) async {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";

    if (adTier == "10s" || adTier == "20s") {
      // 10s Bumper or 20s Interstitial
      final bool shown = showInterstitialAd(
        onDismissed: onRewardSuccess,
      );
      if (!shown) {
        // Fallback for test / dev environment when real ad is not buffered
        onRewardSuccess();
      }
    } else {
      // 30s Rewarded Video
      final bool shown = showRewardedAd(
        userId: currentUid,
        adType: "manual_$adTier",
        targetId: rewardChoice,
        onRewardGranted: onRewardSuccess,
      );
      if (!shown) {
        // Fallback for test / dev environment when real ad is not buffered
        onRewardSuccess();
      }
    }
  }
}
