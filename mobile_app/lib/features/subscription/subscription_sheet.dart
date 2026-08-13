import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/theme/app_theme.dart';
import 'payment_service.dart';

class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key});

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  bool _isProcessing = false;
  String _selectedPlanType = 'monthly'; // 'fast_pass' (₹9), 'photo_pass' (₹19), 'monthly' (₹99)

  String? _activePassBadge;
  bool _hasActivePass = false;

  @override
  void initState() {
    super.initState();
    _fetchActivePassStatus();

    PaymentService.instance.initialize(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  Future<void> _fetchActivePassStatus() async {
    try {
      final response = await ApiClient.instance.dio.get('/payments/active-pass');
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _hasActivePass = data['has_active_pass'] ?? false;
            _activePassBadge = data['badge_text'];
          });
        }
      }
    } catch (_) {
      // Non-blocking fallback
    }
  }

  @override
  void dispose() {
    PaymentService.instance.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ApiClient.instance.verifyPayment(
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
        planType: _selectedPlanType,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Payment verification notice: ${e.toString()}');
      }
    }

    await StorageManager.instance.setPremiumStatus(true);
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Successful & Verified! ID: ${response.paymentId}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Cancelled/Failed: ${response.message}'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (kDebugMode) {
      print('External Wallet Selected: ${response.walletName}');
    }
  }

  Future<void> _completeSimulatedPayment(String orderId) async {
    await StorageManager.instance.setPremiumStatus(true);
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pass Activated! Order ID: $orderId'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _initiateSachetPayment() async {
    setState(() => _isProcessing = true);

    try {
      final success = await PaymentService.instance.startSachetCheckout(
        planType: _selectedPlanType,
      );

      if (kIsWeb && success) {
        await _completeSimulatedPayment('order_web_simulated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Razorpay Checkout exception: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 32, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              const Text(
                'UR Heart Passes & Pro',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Countdown Expiry Badge
          if (_hasActivePass && _activePassBadge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  Text(
                    _activePassBadge!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                  ),
                ],
              ),
            ),

          // 3-Option Pass Selector Cards with Explicit Validity Tags
          Row(
            children: [
              _buildPlanTile('fast_pass', '⚡ Direct Invite', '₹9', 'Valid for 24 Hours'),
              const SizedBox(width: 8),
              _buildPlanTile('photo_pass', '📷 Photo Pass', '₹19', 'Valid for 24 Hours'),
              const SizedBox(width: 8),
              _buildPlanTile('monthly', '👑 Pro Monthly', '₹99', 'Valid for 30 Days'),
            ],
          ),
          const SizedBox(height: 20),

          // Features Matrix
          const Column(
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.offline_bolt_outlined, color: Colors.greenAccent),
                title: Text('Instant Direct Message & Photo Access', style: TextStyle(color: Colors.white)),
                subtitle: Text('Bypass swipe queues & message immediately', style: TextStyle(color: Colors.grey)),
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.block, color: Colors.greenAccent),
                title: Text('100% Zero Ad Experience', style: TextStyle(color: Colors.white)),
                subtitle: Text('Bypass native cards, 20-skip interstitials, & chat video ads', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pay Action Button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _initiateSachetPayment,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet, color: Colors.white),
            label: Text(
              _isProcessing
                  ? 'Connecting to Razorpay...'
                  : 'Pay ${_getPlanPriceLabel()} via UPI (${_getPlanValidityLabel()})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _getPlanPriceLabel() {
    if (_selectedPlanType == 'fast_pass' || _selectedPlanType == 'chai_invite') return '₹9';
    if (_selectedPlanType == 'photo_pass') return '₹19';
    return '₹99';
  }

  String _getPlanValidityLabel() {
    if (_selectedPlanType == 'monthly') return 'Valid 30 Days';
    return 'Valid 24 Hours';
  }

  Widget _buildPlanTile(String planKey, String title, String price, String validitySubtitle) {
    final bool isSelected = _selectedPlanType == planKey || (_selectedPlanType == 'chai_invite' && planKey == 'fast_pass');

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPlanType = planKey),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  validitySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
