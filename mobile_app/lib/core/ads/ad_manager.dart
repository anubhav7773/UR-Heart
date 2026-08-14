import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../network/api_client.dart';
import '../security/storage_manager.dart';

class AdConfig {
  static const String rewardedAdUnitId = AdManager.rewardedAdUnitId;
  static const String nativeAdUnitId = AdManager.nativeAdUnitId;
  static const String interstitialAdUnitId = AdManager.interstitialAdUnitId;
  static const String appOpenAdUnitId = AdManager.appOpenAdUnitId;
}

class AdManager {
  static final AdManager instance = AdManager._internal();
  factory AdManager() => instance;
  AdManager._internal();

  // Standard Test Ad Unit IDs (Google AdMob Specification)
  static const String nativeAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // Remote Config Defaults
  int inFeedAdInterval = 5;
  int skipInterstitialThreshold = 20;
  int appOpenAdCapMinutes = 30;
  int inChatAdIntervalSeconds = 300;
  int inChatAdDurationSeconds = 10;
  int freeDailyDmLimit = 1;

  int _localSkipCount = 0;
  DateTime? _lastAppOpenAdTime;

  // Rewarded Video Ad Cache State
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  int get localSkipCount => _localSkipCount;

  void loadRewardedAd() {
    if (kIsWeb) return;
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;
    try {
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
            if (kDebugMode) print('AdManager: RewardedAd loaded successfully.');
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            if (kDebugMode) print('AdManager: RewardedAd failed to load: $error');
          },
        ),
      );
    } catch (e) {
      _rewardedAd = null;
      _isRewardedAdLoading = false;
      if (kDebugMode) print('AdManager: Exception loading RewardedAd: $e');
    }
  }

  void showRewardedAd({required Function() onRewardEarned, Function()? onFailed}) {
    if (kIsWeb) {
      // In web preview, directly reward the user
      logAdImpression('rewarded_video');
      onRewardEarned();
      return;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd(); // Preload next ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          if (onFailed != null) onFailed();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        logAdImpression('rewarded_video');
        onRewardEarned();
      });
    } else {
      if (onFailed != null) onFailed();
      loadRewardedAd();
    }
  }

  Future<void> fetchRemoteConfig() async {
    try {
      final response = await ApiClient.instance.getAdConfig();
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        inFeedAdInterval = data['in_feed_ad_interval'] ?? 5;
        skipInterstitialThreshold = data['skip_interstitial_threshold'] ?? 20;
        appOpenAdCapMinutes = data['app_open_ad_cap_minutes'] ?? 30;
        inChatAdIntervalSeconds = data['in_chat_ad_interval_seconds'] ?? 300;
        inChatAdDurationSeconds = data['in_chat_ad_duration_seconds'] ?? 10;
        freeDailyDmLimit = data['free_daily_dm_limit'] ?? 1;
      }
    } catch (e) {
      if (kDebugMode) {
        print('AdManager: Failed to fetch remote config, using defaults.');
      }
    }
  }

  Future<bool> processSkipAction() async {
    final bool isPremium = await StorageManager.instance.isPremium();
    if (isPremium) {
      return false; // Subscribers bypass interstitial ads
    }

    _localSkipCount++;
    if (_localSkipCount >= skipInterstitialThreshold) {
      _localSkipCount = 0;
      await StorageManager.instance.saveSkipCount(0);
      await logAdImpression('interstitial_skip');
      return true; // Trigger 20-30s interstitial ad
    }

    await StorageManager.instance.saveSkipCount(_localSkipCount);
    return false;
  }

  bool shouldShowAppOpenAd() {
    if (_lastAppOpenAdTime == null) {
      _lastAppOpenAdTime = DateTime.now();
      return true;
    }

    final diff = DateTime.now().difference(_lastAppOpenAdTime!).inMinutes;
    if (diff >= appOpenAdCapMinutes) {
      _lastAppOpenAdTime = DateTime.now();
      return true;
    }
    return false;
  }

  Future<void> logAdImpression(String adUnitType) async {
    try {
      await ApiClient.instance.logAdEvent(
        adUnitType: adUnitType,
        eventType: 'impression',
        networkProvider: 'AdMob',
        ecpmEstimate: 0.45,
      );
    } catch (e) {
      // Background analytics log failure handler
    }
  }
}
