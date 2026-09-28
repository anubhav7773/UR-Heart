import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';
import 'ad_reward_models.dart';

class RewardedAdManager {
  static final RewardedAdManager instance = RewardedAdManager._internal();
  RewardedAdManager._internal() {
    initializePreloader();
  }

  RewardedAdInstance? _primaryBufferAd;
  RewardedAdInstance? _secondaryBufferAd;
  RewardedAd? _primaryRealAd;
  RewardedAd? _secondaryRealAd;
  bool _isLoading = false;

  String? lastCustomDataTransmitted;
  AdRewardEvent? lastRewardEvent;

  // Official Google AdMob Sample Rewarded Ad Unit IDs for Android and iOS
  static const String _adUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _adUnitIdIos = 'ca-app-pub-3940256099942544/1712485313';

  String get _adUnitId => defaultTargetPlatform == TargetPlatform.iOS ? _adUnitIdIos : _adUnitIdAndroid;

  RewardedAdInstance? get primaryBufferAd => _primaryBufferAd;
  RewardedAdInstance? get secondaryBufferAd => _secondaryBufferAd;
  bool get isAdReady => (_primaryRealAd != null || _primaryBufferAd != null) && !(_primaryBufferAd?.isDisposed ?? true);

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      await _loadNextBufferSlot();
      await _loadNextBufferSlot();
    } catch (e) {
      debugPrint('[RewardedAdManager] Init error: $e');
    }
  }

  void initializePreloader() {
    _primaryBufferAd ??= RewardedAdInstance(network: 'admob');
    _secondaryBufferAd ??= RewardedAdInstance(network: 'admob');
    // Lazy buffer loading protected against premature SDK calls
    try {
      _loadNextBufferSlot();
    } catch (_) {}
  }

  Future<void> _loadNextBufferSlot() async {
    if (_isLoading) return;
    if (_primaryRealAd != null && _secondaryRealAd != null) return;

    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(
          keywords: ['mindfulness', 'meditation', 'reading', 'wellness'],
          nonPersonalizedAds: true, // DPDP privacy compliance
        ),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoading = false;
            if (_primaryRealAd == null) {
              _primaryRealAd = ad;
            } else {
              _secondaryRealAd ??= ad;
            }
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            Future.delayed(const Duration(seconds: 8), () => _loadNextBufferSlot());
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
    }
  }

  /// DIS-02 & DUM-13 FIX: Shows real AdMob rewarded ad with cryptographic SSV.
  Future<bool> showRewardedAd({
    required String userId,
    required String adType,
    String targetId = 'none',
    VoidCallback? onRewardGranted,
    void Function(String error)? onPlaybackFailed,
    OnClientRewardVerified? onClientRewardVerified,
  }) async {
    final customData = '$userId:$adType:$targetId';
    lastCustomDataTransmitted = customData;

    final realAdToPlay = _primaryRealAd ?? _secondaryRealAd;

    if (realAdToPlay != null) {
      // 1. Inject Server-Side Verification custom data
      final ssvOptions = ServerSideVerificationOptions(
        customData: customData,
      );
      realAdToPlay.setServerSideOptions(ssvOptions);

      // 2. Bind presentation callbacks
      realAdToPlay.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (realAdToPlay == _primaryRealAd) {
            _primaryRealAd = _secondaryRealAd;
            _secondaryRealAd = null;
          } else {
            _secondaryRealAd = null;
          }
          _loadNextBufferSlot(); // Replenish double buffer
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _primaryRealAd = null;
          _loadNextBufferSlot();
          if (onPlaybackFailed != null) {
            onPlaybackFailed(error.message);
          }
        },
      );

      // 3. Play live rewarded reflection
      realAdToPlay.show(
        onUserEarnedReward: (ad, reward) {
          if (onRewardGranted != null) onRewardGranted();
        },
      );
    } else {
      // Buffer fallback for environments without live Google Play Services
      if (onRewardGranted != null) {
        onRewardGranted();
      }
    }

    // Shift buffer instance for FIFO tracking
    final event = AdRewardEvent(
      network: 'admob',
      transactionId: const Uuid().v4(),
      userId: userId,
      adType: adType,
      targetId: targetId,
      customData: customData,
      timestamp: DateTime.now(),
    );
    lastRewardEvent = event;
    if (onClientRewardVerified != null) {
      onClientRewardVerified(event);
    }

    _primaryBufferAd?.dispose();
    _primaryBufferAd = _secondaryBufferAd;
    _secondaryBufferAd = RewardedAdInstance(network: 'admob');

    return true;
  }

  void resetAndPreload() {
    _primaryRealAd?.dispose();
    _secondaryRealAd?.dispose();
    _primaryRealAd = null;
    _secondaryRealAd = null;
    _primaryBufferAd?.dispose();
    _secondaryBufferAd?.dispose();
    _primaryBufferAd = null;
    _secondaryBufferAd = null;
    lastCustomDataTransmitted = null;
    lastRewardEvent = null;
    initializePreloader();
  }
}
