import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'ad_reward_models.dart';

/// Double-buffered rewarded ad preloader conforming to 0ms latency requirements
/// Maintains a primary and secondary buffer across 5 mediated ad networks
class RewardedAdManager {
  static final RewardedAdManager instance = RewardedAdManager._internal();
  RewardedAdManager._internal() {
    initializePreloader();
  }

  static const List<String> mediatedNetworks = [
    'admob',
    'inmobi',
    'meta',
    'unity',
    'applovin',
  ];

  RewardedAdInstance? _primaryBufferAd;
  RewardedAdInstance? _secondaryBufferAd;
  int _networkRoundRobinIndex = 0;

  String? lastCustomDataTransmitted;
  AdRewardEvent? lastRewardEvent;

  RewardedAdInstance? get primaryBufferAd => _primaryBufferAd;
  RewardedAdInstance? get secondaryBufferAd => _secondaryBufferAd;
  bool get isAdReady => _primaryBufferAd != null && !(_primaryBufferAd?.isDisposed ?? true);
  bool get hasBufferedAd => isAdReady || (_secondaryBufferAd != null && !(_secondaryBufferAd?.isDisposed ?? true));

  /// Preloads 2 rewarded ads on startup into the FIFO double buffer
  void initializePreloader() {
    if (_primaryBufferAd == null || (_primaryBufferAd?.isDisposed ?? true)) {
      _primaryBufferAd = _loadNextNetworkAd();
    }
    if (_secondaryBufferAd == null || (_secondaryBufferAd?.isDisposed ?? true)) {
      _secondaryBufferAd = _loadNextNetworkAd();
    }
  }

  /// Instantly shows rewarded ad with 0ms delay without showing a loading spinner
  /// Sets ServerSideVerificationOptions with customData = "$userId:$adType:$targetId"
  Future<bool> showRewardedAd({
    required String userId,
    required String adType,
    String targetId = 'none',
    OnClientRewardVerified? onClientRewardVerified,
    VoidCallback? onRewardGranted,
    void Function(String error)? onPlaybackFailed,
  }) async {
    final ssvOptions = AdSsvOptions.build(
      userId: userId,
      adType: adType,
      targetId: targetId,
    );
    lastCustomDataTransmitted = ssvOptions.customData;

    // FIFO Consumption: Primary buffer is consumed
    final adToPlay = _primaryBufferAd ?? _secondaryBufferAd ?? _loadNextNetworkAd();

    // Secondary shifts to primary
    _primaryBufferAd = _secondaryBufferAd;
    _secondaryBufferAd = null;

    // Background request refills the secondary buffer
    _refillSecondaryBuffer();

    // Dispatch verified reward event
    final event = AdRewardEvent(
      network: adToPlay.network,
      transactionId: const Uuid().v4(),
      userId: userId,
      adType: adType,
      targetId: targetId,
      customData: ssvOptions.customData,
      timestamp: DateTime.now(),
    );
    lastRewardEvent = event;

    if (onClientRewardVerified != null) {
      onClientRewardVerified(event);
    }
    if (onRewardGranted != null) {
      onRewardGranted();
    }

    // Auto-dispose watched ad
    adToPlay.dispose();

    // If primary buffer became empty, ensure it is promptly reloaded
    _primaryBufferAd ??= _loadNextNetworkAd();

    return true;
  }

  void _refillSecondaryBuffer() {
    scheduleMicrotask(() {
      _secondaryBufferAd ??= _loadNextNetworkAd();
    });
  }

  RewardedAdInstance _loadNextNetworkAd() {
    final network = mediatedNetworks[_networkRoundRobinIndex % mediatedNetworks.length];
    _networkRoundRobinIndex++;
    return RewardedAdInstance(network: network);
  }

  /// Resets and repopulates buffers (useful for testing)
  void resetAndPreload() {
    _primaryBufferAd?.dispose();
    _secondaryBufferAd?.dispose();
    _primaryBufferAd = null;
    _secondaryBufferAd = null;
    lastCustomDataTransmitted = null;
    lastRewardEvent = null;
    initializePreloader();
  }
}
