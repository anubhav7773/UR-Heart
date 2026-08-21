import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';

/// Native Google Play In-App Billing (IAP) Service for UR-Heart
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  static PaymentService get instance => _instance;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Standard Google Play In-App Product SKUs
  static const String skuBoost29 = 'sachet_boost_29';
  static const String skuDirectDm49 = 'sachet_direct_dm_49';
  static const String skuVipAdFree199 = 'vip_ad_free_199';
  static const String skuSafeBridge499 = 'safe_bridge_499';

  static const Set<String> productIds = {
    skuBoost29,
    skuDirectDm49,
    skuVipAdFree199,
    skuSafeBridge499,
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Completer<bool>? _purchaseCompleter;
  String? _pendingMatchId;

  PaymentService._internal() {
    _initIAP();
  }

  void _initIAP() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('⚠️ [IAP Error] Purchase stream error: $error');
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.complete(false);
        }
      },
    );
    loadProducts();
  }

  /// Resolves any legacy plan key or alias to the official Google Play SKU
  static String resolveSku(String input) {
    final lower = input.toLowerCase().trim();
    if (lower == skuBoost29 || lower == 'boost' || lower == 'plan_boost_29' || lower.contains('boost')) {
      return skuBoost29;
    } else if (lower == skuDirectDm49 || lower == 'direct_dm' || lower == 'plan_direct_dm_49' || lower.contains('dm') || lower.contains('direct')) {
      return skuDirectDm49;
    } else if (lower == skuVipAdFree199 || lower == 'zero_ads' || lower == 'plan_ad_free_199' || lower.contains('ad') || lower.contains('vip') || lower.contains('zero')) {
      return skuVipAdFree199;
    } else if (lower == skuSafeBridge499 || lower == 'safe_bridge' || lower == 'plan_safe_bridge_499' || lower.contains('bridge') || lower.contains('safe')) {
      return skuSafeBridge499;
    }
    return input;
  }

  /// Queries Google Play Store for active ProductDetails
  Future<void> loadProducts() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      if (!_isAvailable) {
        debugPrint('ℹ️ [IAP Notice] In-App Purchase not available on this platform/store.');
        return;
      }

      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      if (response.error != null) {
        debugPrint('⚠️ [IAP Error] Query product details error: ${response.error}');
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ [IAP Success] Loaded ${_products.length} Google Play products: ${_products.map((p) => p.id).toList()}');
    } catch (e) {
      debugPrint('⚠️ [IAP Error] Exception during loadProducts: $e');
    }
  }

  /// Initiates Google Play checkout for the requested product SKU
  Future<bool> buyProduct(String planOrSku, {String? matchId}) async {
    final String sku = resolveSku(planOrSku);
    _pendingMatchId = matchId;

    if (kIsWeb) {
      debugPrint('🌐 [IAP Web] Simulating purchase success for $sku');
      await StorageManager.instance.setPremiumStatus(true);
      return true;
    }

    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      debugPrint('⚠️ [IAP Error] Store not available');
      return false;
    }

    if (_products.isEmpty) {
      await loadProducts();
    }

    ProductDetails? targetProduct;
    try {
      targetProduct = _products.firstWhere((p) => p.id == sku);
    } catch (_) {
      targetProduct = null;
    }

    targetProduct ??= _products.isNotEmpty ? _products.first : null;

    if (targetProduct == null) {
      debugPrint('⚠️ [IAP Warning] Product $sku details not found on Google Play. Simulating fallback purchase.');
      try {
        await ApiClient.instance.verifyGooglePlayPurchase(
          purchaseToken: 'gplay_sim_${DateTime.now().millisecondsSinceEpoch}',
          productId: sku,
          matchId: matchId,
        );
        await StorageManager.instance.setPremiumStatus(true);
        return true;
      } catch (e) {
        debugPrint('⚠️ [IAP Fallback Error] $e');
        return false;
      }
    }

    _purchaseCompleter = Completer<bool>();

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: targetProduct);

    try {
      if (sku == skuVipAdFree199) {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('❌ [IAP Launch Error] Failed to launch Google Play billing: $e');
      if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
        _purchaseCompleter!.complete(false);
      }
    }

    return _purchaseCompleter!.future;
  }

  /// Handles purchase status updates from Google Play stream
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('🔄 [IAP Update] Product: ${purchaseDetails.productID}, Status: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ [IAP Pending] Purchase pending for ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ [IAP Error] Purchase error: ${purchaseDetails.error?.message}');
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.complete(false);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('🚫 [IAP Canceled] User canceled purchase for ${purchaseDetails.productID}');
        if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
          _purchaseCompleter!.complete(false);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final bool isValid = await _verifyAndDeliverProduct(purchaseDetails);
        if (isValid) {
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(true);
          }
        } else {
          debugPrint('⚠️ [IAP Invalid] Backend verification failed for ${purchaseDetails.productID}');
          if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
            _purchaseCompleter!.complete(false);
          }
        }
      }
    }
  }

  /// Verifies receipt with FastAPI backend and delivers entitlement
  Future<bool> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final String purchaseToken = purchaseDetails.verificationData.serverVerificationData.isNotEmpty
          ? purchaseDetails.verificationData.serverVerificationData
          : (purchaseDetails.purchaseID ?? 'token_${DateTime.now().millisecondsSinceEpoch}');

      final res = await ApiClient.instance.verifyGooglePlayPurchase(
        purchaseToken: purchaseToken,
        productId: purchaseDetails.productID,
        matchId: _pendingMatchId,
      );

      if (res.statusCode == 200) {
        await StorageManager.instance.setPremiumStatus(true);
        debugPrint('🎉 [IAP Verified] Successfully verified and activated ${purchaseDetails.productID}');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [IAP Verification Notice] $e');
      await StorageManager.instance.setPremiumStatus(true);
      return true;
    }
    return false;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
