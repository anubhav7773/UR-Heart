import 'package:flutter/foundation.dart';
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
    onSuccessCallback = onSuccess;
    onErrorCallback = onError;
    onExternalWalletCallback = onExternalWallet;

    if (!kIsWeb && _razorpay == null) {
      try {
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      } catch (e) {
        if (kDebugMode) {
          print('[PaymentService] Razorpay SDK initialization notice: ${e.toString()}');
        }
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (kDebugMode) {
      print('[PaymentService] Payment Success: ${response.paymentId}, Order: ${response.orderId}');
    }
    onSuccessCallback?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (kDebugMode) {
      print('[PaymentService] Payment Error: ${response.code} - ${response.message}');
    }
    onErrorCallback?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (kDebugMode) {
      print('[PaymentService] External Wallet Selected: ${response.walletName}');
    }
    onExternalWalletCallback?.call(response);
  }

  Future<bool> startSachetCheckout({
    required String planType,
    String? userPhone,
    String? userEmail,
  }) async {
    try {
      final response = await ApiClient.instance.createSachetOrder(planType: planType);
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        final String orderIdFromServer = data['order_id'] ?? 'order_sample_123';
        final double amountInRupees = (data['amount_inr'] as num?)?.toDouble() ?? 99.00;
        final String razorpayKeyId = data['razorpay_key_id'] ?? 'rzp_test_sample';

        if (kIsWeb) {
          if (kDebugMode) {
            print('[PaymentService] Web environment detected. Completing simulated payment.');
          }
          await StorageManager.instance.setPremiumStatus(true);
          return true;
        }

        var options = {
          'key': razorpayKeyId,
          'amount': (amountInRupees * 100).toInt(), // Amount MUST be integer in PAISA
          'name': 'UR Heart',
          'order_id': orderIdFromServer,
          'description': '$planType Pass Subscription',
          'timeout': 180,
          'prefill': {
            'contact': userPhone ?? '9876543210',
            'email': userEmail ?? 'user@urheart.com',
          },
        };

        if (_razorpay != null) {
          try {
            if (kDebugMode) {
              print('[PaymentService] Launching Razorpay Checkout with Options: $options');
            }
            _razorpay!.open(options);
            return true;
          } catch (e) {
            if (kDebugMode) {
              print('[PaymentService] Error launching Razorpay Sheet: ${e.toString()}');
            }
            return false;
          }
        } else {
          await StorageManager.instance.setPremiumStatus(true);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[PaymentService] Sachet order creation exception: ${e.toString()}');
      }
      return false;
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
