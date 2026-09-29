import 'package:uuid/uuid.dart';

/// Supported mediated ad networks in the 5-network waterfall
enum AdMediatedNetwork {
  admob,
  inmobi,
  meta,
  unity,
  applovin,
}

/// Standardized ad placement codes conforming to SSV backend contract
class AdPlacementTypes {
  const AdPlacementTypes._();

  static const String quickReflection = 'quick_reflection';
  static const String deepResonance = 'deep_resonance';
  static const String whatsappReveal = 'whatsapp_reveal';
  static const String morningHarvestUnlock = 'morning_harvest_unlock';
  static const String dailyStreakBoost = 'daily_streak_boost';
}

/// Server-Side Verification (SSV) customData configuration
class AdSsvOptions {
  final String userId;
  final String adType;
  final String targetId;
  final String customData;

  const AdSsvOptions({
    required this.userId,
    required this.adType,
    this.targetId = 'none',
    required this.customData,
  });

  /// Factory enforcing strict customData contract: "{userId}:{adType}:{targetId}"
  factory AdSsvOptions.build({
    required String userId,
    required String adType,
    String targetId = 'none',
  }) {
    final payload = '$userId:$adType:$targetId';
    return AdSsvOptions(
      userId: userId,
      adType: adType,
      targetId: targetId,
      customData: payload,
    );
  }
}

/// Client reward event dispatched upon verified completion
class AdRewardEvent {
  final String network;
  final String transactionId;
  final String userId;
  final String adType;
  final String targetId;
  final String customData;
  final DateTime timestamp;

  const AdRewardEvent({
    required this.network,
    required this.transactionId,
    required this.userId,
    required this.adType,
    required this.targetId,
    required this.customData,
    required this.timestamp,
  });
}

/// Callback invoked when a rewarded ad completes and SSV is acknowledged
typedef OnClientRewardVerified = void Function(AdRewardEvent event);

/// Internal double-buffer ad representation
class RewardedAdInstance {
  final String id;
  final String network;
  final DateTime loadedAt;
  bool isDisposed;

  RewardedAdInstance({
    String? id,
    required this.network,
    DateTime? loadedAt,
    this.isDisposed = false,
  })  : id = id ?? const Uuid().v4(),
        loadedAt = loadedAt ?? DateTime.now();

  void dispose() {
    isDisposed = true;
  }
}
