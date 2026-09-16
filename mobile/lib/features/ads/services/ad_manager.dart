import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Multi-Network Ad Preload Buffer and SSV Custom Data Engine
/// Implements dual-slot background preload buffer to eliminate ad loading latency.
class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  RewardedAd? _preloadedRewardedAd;
  InterstitialAd? _preloadedInterstitialAd;
  bool _isRewardedLoading = false;
  bool _isInterstitialLoading = false;

  // ASI Verticals Production Ad Unit IDs (Google test IDs for development)
  final String rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final String interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

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
}
