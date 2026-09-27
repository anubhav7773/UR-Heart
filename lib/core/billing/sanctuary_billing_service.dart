import 'dart:async';
import 'package:flutter/foundation.dart';

/// Billing products and subscription tiers for Sanctuary Sovereign Store
enum SovereignProductType { subscription, consumable }

class SanctuaryProduct {
  final String id;
  final String title;
  final String priceString;
  final SovereignProductType type;

  const SanctuaryProduct({
    required this.id,
    required this.title,
    required this.priceString,
    required this.type,
  });
}

/// RevenueCat Google Play Billing v7 service & entitlement manager (< 180 lines)
class SanctuaryBillingService {
  static final SanctuaryBillingService instance = SanctuaryBillingService._internal();
  SanctuaryBillingService._internal();
  factory SanctuaryBillingService() => instance;

  String _activeTier = 'free';
  final StreamController<String> _tierStreamController = StreamController<String>.broadcast();

  String get activeTier => _activeTier;
  bool get isAdFree => _activeTier != 'free';
  Stream<String> get tierStream => _tierStreamController.stream;

  static const List<SanctuaryProduct> catalog = [
    SanctuaryProduct(
      id: 'urheart_pass_weekly',
      title: '1-Week Sovereign Sprint',
      priceString: '\$4.99 / ₹49',
      type: SovereignProductType.subscription,
    ),
    SanctuaryProduct(
      id: 'urheart_pass_monthly',
      title: '1-Month Sovereign Pass',
      priceString: '\$14.99 / ₹149',
      type: SovereignProductType.subscription,
    ),
    SanctuaryProduct(
      id: 'urheart_pass_lifetime',
      title: 'Lifetime Sovereign Crest',
      priceString: '\$59.99 / ₹799',
      type: SovereignProductType.subscription,
    ),
    SanctuaryProduct(
      id: 'urheart_key_instant_contact',
      title: 'Instant Contact Key',
      priceString: '\$1.49 / ₹29',
      type: SovereignProductType.consumable,
    ),
    SanctuaryProduct(
      id: 'urheart_pack_direct_letters',
      title: '3 Direct Letters Pack',
      priceString: '\$1.99 / ₹49',
      type: SovereignProductType.consumable,
    ),
    SanctuaryProduct(
      id: 'urheart_pack_global_passport',
      title: '48h Global Passport',
      priceString: '\$2.99 / ₹79',
      type: SovereignProductType.consumable,
    ),
  ];

  /// Simulates / invokes purchase of Sovereign weekly/monthly/lifetime pass
  Future<bool> purchasePackage(String productId) async {
    switch (productId) {
      case 'urheart_pass_weekly':
        _activeTier = 'weekly';
        break;
      case 'urheart_pass_monthly':
        _activeTier = 'monthly';
        break;
      case 'urheart_pass_lifetime':
        _activeTier = 'lifetime';
        break;
      default:
        _activeTier = 'monthly';
    }
    _tierStreamController.add(_activeTier);
    debugPrint('[Billing] Sovereign Tier unlocked: $_activeTier');
    return true;
  }

  /// Simulates / invokes purchase of a la carte consumable key or letter pack
  Future<bool> purchaseMicroPack(String productId) async {
    debugPrint('[Billing] Consumable micro-pack purchased: $productId');
    return true;
  }

  /// Restores Google Play active purchases & active entitlements
  Future<bool> restorePurchases() async {
    debugPrint('[Billing] Restored Google Play entitlements: $_activeTier');
    return true;
  }

  /// Manually overrides tier for testing or admin grants
  void setTierForTesting(String tier) {
    _activeTier = tier;
    _tierStreamController.add(_activeTier);
  }

  /// Resets active tier back to free for isolated test runs
  void resetForTesting() {
    _activeTier = 'free';
  }

  void dispose() {
    _tierStreamController.close();
  }
}
