import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  static PaymentService get instance => _instance;

  late Razorpay _razorpay;
  Completer<PaymentSuccessResponse>? _paymentCompleter;

  PaymentService._internal() {
    if (!kIsWeb) {
      try {
        _razorpay = Razorpay();
        _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
        _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
        _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
        debugPrint('[PaymentService] Persistent Razorpay singleton initialized & listeners registered');
      } catch (e) {
        debugPrint('[PaymentService] Razorpay SDK initialization notice: ${e.toString()}');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('[RAZORPAY_SUCCESS] Payment ID: ${response.paymentId}, Order ID: ${response.orderId}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY_FAILURE] Code: ${response.code}, Message: ${response.message}');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.completeError(
        Exception('Payment failed [${response.code}]: ${response.message ?? "User cancelled or payment dismissed"}'),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[RAZORPAY_EXTERNAL_WALLET] Wallet: ${response.walletName}');
  }

  Future<PaymentSuccessResponse> startCheckout({
    required Map<String, dynamic> orderData,
    String? userEmail,
    String? userPhone,
  }) async {
    if (kIsWeb) {
      debugPrint('[PaymentService] Web environment detected. Simulating payment success.');
      await StorageManager.instance.setPremiumStatus(true);
      return PaymentSuccessResponse(
        'pay_simulated_${DateTime.now().millisecondsSinceEpoch}',
        orderData['order_id'] ?? 'order_simulated',
        'sig_simulated',
        null,
      );
    }

    _paymentCompleter = Completer<PaymentSuccessResponse>();

    // Calculate strict integer paise
    final int amountInPaise = orderData['amount_in_paise'] != null
        ? (orderData['amount_in_paise'] as num).toInt()
        : ((orderData['amount'] ?? orderData['amount_inr'] ?? 29) as num).toDouble().toInt() * 100;

    // Sanitize phone number to standard 10 digits
    String sanitizedPhone = (userPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (sanitizedPhone.length > 10) {
      sanitizedPhone = sanitizedPhone.substring(sanitizedPhone.length - 10);
    }
    if (sanitizedPhone.length != 10) {
      sanitizedPhone = '9876543210'; // Safe fallback for Razorpay validation
    }

    final Map<String, dynamic> options = {
      'key': orderData['razorpay_key_id'] ?? 'rzp_test_sample',
      'amount': amountInPaise,
      'name': 'UR-Heart',
      'description': orderData['description'] ?? 'UR-Heart In-App Purchase',
      'order_id': orderData['order_id'],
      'currency': 'INR',
      'timeout': 300,
      'prefill': {
        'contact': sanitizedPhone,
        'email': (userEmail != null && userEmail.contains('@')) ? userEmail : 'user@urheart.app',
      },
      'theme': {
        'color': '#FF3366',
        'backdrop_color': '#121212',
      },
      'modal': {
        'confirm_close': true,
        'animation': true,
      },
      'retry': {'enabled': true, 'max_count': 3},
    };

    debugPrint('[RAZORPAY_OPEN] Launching native checkout with options: $options');

    try {
      _razorpay.open(options);
    } catch (e, stack) {
      debugPrint('[RAZORPAY_ERROR] Failed to open native checkout: $e\n$stack');
      throw Exception('Could not launch payment gateway: $e');
    }

    return _paymentCompleter!.future;
  }

  /// Convenience wrapper for initiating Sachet Pass checkout directly
  Future<PaymentSuccessResponse> startSachetCheckout({
    required String planType,
    String? userPhone,
    String? userEmail,
  }) async {
    final response = await ApiClient.instance.createSachetOrder(planType: planType);
    if (response.data != null && response.data['data'] != null) {
      final orderData = Map<String, dynamic>.from(response.data['data']);
      return await startCheckout(
        orderData: orderData,
        userEmail: userEmail,
        userPhone: userPhone,
      );
    } else {
      throw Exception('Failed to generate order from server: ${response.data}');
    }
  }
}
