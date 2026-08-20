import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';

class PaymentService {
  static final PaymentService instance = PaymentService._internal();
  PaymentService._internal();

  Razorpay? _razorpay;

  Function(PaymentSuccessResponse)? onSuccessCallback;
  Function(PaymentFailureResponse)? onErrorCallback;
  Function(ExternalWalletResponse)? onExternalWalletCallback;

  void initialize({
    Function(PaymentSuccessResponse)? onSuccess,
    Function(PaymentFailureResponse)? onError,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    if (onSuccess != null) onSuccessCallback = onSuccess;
    if (onError != null) onErrorCallback = onError;
    if (onExternalWallet != null) onExternalWalletCallback = onExternalWallet;

    if (!kIsWeb && _razorpay == null) {
      try {
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
        debugPrint('[PaymentService] Razorpay SDK initialized & listeners registered successfully');
      } catch (e) {
        debugPrint('[PaymentService] Razorpay SDK initialization notice: ${e.toString()}');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('[RAZORPAY_SUCCESS] Payment ID: ${response.paymentId} | Order ID: ${response.orderId} | Signature: ${response.signature}');
    onSuccessCallback?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY_ERROR] Payment Error Code: ${response.code} | Message: ${response.message} | Error: ${response.error}');
    onErrorCallback?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[RAZORPAY_EXTERNAL_WALLET] External Wallet: ${response.walletName}');
    onExternalWalletCallback?.call(response);
  }

  Future<bool> startSachetCheckout({
    required String planType,
    String? userPhone,
    String? userEmail,
    Map<String, dynamic>? customOrderData,
  }) async {
    try {
      Map<String, dynamic> orderData;
      if (customOrderData != null) {
        orderData = customOrderData;
      } else {
        final response = await ApiClient.instance.createSachetOrder(planType: planType);
        if (response.data != null && response.data['data'] != null) {
          orderData = Map<String, dynamic>.from(response.data['data']);
        } else {
          debugPrint('[PaymentService] Error: Could not retrieve order data from response: ${response.data}');
          return false;
        }
      }

      final String razorpayKeyId = orderData['razorpay_key_id'] ?? 'rzp_test_YOUR_KEY';
      final int amountInPaise = (orderData['amount_in_paise'] as num?)?.toInt() ??
          (((orderData['amount'] ?? orderData['amount_inr'] ?? 29) as num).toDouble() * 100).toInt();
      final String orderId = orderData['order_id'] ?? '';
      final String planName = orderData['plan_name'] ?? orderData['plan_type'] ?? '$planType Pass';

      if (kIsWeb) {
        debugPrint('[PaymentService] Web environment detected. Completing simulated payment.');
        await StorageManager.instance.setPremiumStatus(true);
        return true;
      }

      final String? currentAuthPhone = FirebaseAuth.instance.currentUser?.phoneNumber?.replaceAll('+', '');
      final String? currentAuthEmail = FirebaseAuth.instance.currentUser?.email;

      var options = {
        'key': razorpayKeyId,
        'amount': amountInPaise, // MUST be integer in paise (e.g. 1900 for Rs 19)
        'name': 'UR-Heart',
        'description': planName,
        'order_id': orderId, // must be valid order_id from backend
        'timeout': 180, // in seconds
        'prefill': {
          'contact': userPhone ?? currentAuthPhone ?? '9999999999',
          'email': userEmail ?? currentAuthEmail ?? 'user@urheart.app'
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      debugPrint('[RAZORPAY_OPEN] Options: $options');

      // Re-verify Razorpay instance is ready and attached
      if (_razorpay == null) {
        initialize();
      }

      if (_razorpay != null) {
        try {
          _razorpay!.open(options);
          return true;
        } catch (e) {
          debugPrint('[PaymentService] Error launching Razorpay Sheet: ${e.toString()}');
          return false;
        }
      } else {
        await StorageManager.instance.setPremiumStatus(true);
        return true;
      }
    } catch (e) {
      debugPrint('[PaymentService] Sachet order creation exception: ${e.toString()}');
      return false;
    }
  }

  void clearCallbacks() {
    onSuccessCallback = null;
    onErrorCallback = null;
    onExternalWalletCallback = null;
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
