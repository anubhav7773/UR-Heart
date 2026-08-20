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
  Completer<PaymentSuccessResponse>? _completer;

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
    debugPrint('[RAZORPAY_SUCCESS] PaymentId: ${response.paymentId}, OrderId: ${response.orderId}');
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY_ERROR_RAW] Code: ${response.code}, Message: ${response.message}');
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(
        Exception('Razorpay Error [${response.code}]: ${response.message ?? "User closed payment sheet"}'),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[RAZORPAY_WALLET] External wallet selected: ${response.walletName}');
  }

  Future<PaymentSuccessResponse> openCheckout({
    required String orderId,
    required int amountInPaise,
    required String razorpayKeyId,
    required String description,
    String? userEmail,
    String? userPhone,
  }) async {
    if (kIsWeb) {
      debugPrint('[PaymentService] Web environment detected. Simulating payment success.');
      await StorageManager.instance.setPremiumStatus(true);
      return PaymentSuccessResponse(
        'pay_simulated_${DateTime.now().millisecondsSinceEpoch}',
        orderId,
        'sig_simulated',
        null,
      );
    }

    _completer = Completer<PaymentSuccessResponse>();

    // 1. Sanitize Phone to 10 Digits
    String sanitizedPhone = (userPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (sanitizedPhone.length > 10) {
      sanitizedPhone = sanitizedPhone.substring(sanitizedPhone.length - 10);
    }
    if (sanitizedPhone.length != 10) {
      sanitizedPhone = '9999999999'; // Fallback to pass SDK validation
    }

    // 2. Sanitize Email
    String sanitizedEmail = (userEmail != null && userEmail.contains('@'))
        ? userEmail.trim()
        : 'user@urheart.app';

    // 3. Strict Options Map (No Nulls, Strict Types)
    final Map<String, dynamic> options = {
      'key': razorpayKeyId.trim(),
      'amount': amountInPaise, // Strict int (e.g. 2900, 4900)
      'name': 'UR-Heart',
      'description': description.trim(),
      'order_id': orderId.trim(),
      'currency': 'INR',
      'timeout': 300,
      'prefill': {
        'contact': sanitizedPhone,
        'email': sanitizedEmail,
      },
      'theme': {
        'color': '#FF3366',
        'backdrop_color': '#121212',
      },
      'modal': {
        'confirm_close': true,
      },
      'retry': {
        'enabled': true,
        'max_count': 3,
      },
    };

    debugPrint('[RAZORPAY_DISPATCH] Dispatching options: $options');

    try {
      _razorpay.open(options);
    } catch (e, stack) {
      debugPrint('[RAZORPAY_NATIVE_CRASH] Failed to invoke SDK: $e\n$stack');
      throw Exception('Could not launch payment gateway: $e');
    }

    return _completer!.future;
  }

  /// Convenience wrapper supporting map orderData parameter
  Future<PaymentSuccessResponse> startCheckout({
    required Map<String, dynamic> orderData,
    String? userEmail,
    String? userPhone,
  }) async {
    final int amountInPaise = orderData['amount_in_paise'] != null
        ? (orderData['amount_in_paise'] as num).toInt()
        : ((orderData['amount'] ?? orderData['amount_inr'] ?? 29) as num).toDouble().toInt() * 100;

    final String orderId = (orderData['order_id'] ?? '').toString();
    final String razorpayKeyId = (orderData['razorpay_key_id'] ?? 'rzp_test_sample').toString();
    final String description = (orderData['description'] ?? 'UR-Heart In-App Purchase').toString();

    return await openCheckout(
      orderId: orderId,
      amountInPaise: amountInPaise,
      razorpayKeyId: razorpayKeyId,
      description: description,
      userEmail: userEmail,
      userPhone: userPhone,
    );
  }

  /// Convenience wrapper for initiating Sachet Pass checkout directly
  Future<PaymentSuccessResponse> startSachetCheckout({
    required String planType,
    String? userPhone,
    String? userEmail,
  }) async {
    final response = await ApiClient.instance.createSachetOrder(planType: planType);
    final dynamic raw = response.data?['data'] ?? response.data;
    if (raw != null) {
      final orderData = Map<String, dynamic>.from(raw);
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
