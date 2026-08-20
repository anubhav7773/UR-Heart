import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/theme/app_theme.dart';
import 'payment_service.dart';

class SubscriptionSheet extends StatefulWidget {
  final String? initialPlanType;

  const SubscriptionSheet({
    super.key,
    this.initialPlanType,
  });

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  bool _isProcessing = false;
  late String _selectedPlanType;

  String? _activePassBadge;
  bool _hasActivePass = false;

  @override
  void initState() {
    super.initState();
    _selectedPlanType = widget.initialPlanType ?? 'PLAN_DIRECT_DM_49';
    _fetchActivePassStatus();
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

  Future<void> _initiateSachetPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final selectedPlan = _selectedPlanType;

    try {
      // Step 1: Create order on backend
      final orderResponse = await ApiClient.instance.createSachetOrder(
        planType: selectedPlan,
      );

      if (orderResponse.data == null || orderResponse.data['data'] == null) {
        throw Exception('Failed to generate order from server');
      }
      final orderData = Map<String, dynamic>.from(orderResponse.data['data']);

      // Step 2: Cleanly dismiss the modal bottom sheet FIRST
      navigator.pop(true);

      // Step 3: Crucial delay to let Flutter route animation settle and free the Activity context
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 4: Launch Razorpay via persistent singleton
      final currentUser = FirebaseAuth.instance.currentUser;
      final paymentResult = await PaymentService().startCheckout(
        orderData: orderData,
        userEmail: currentUser?.email,
        userPhone: currentUser?.phoneNumber,
      );

      // Step 5: Verify payment on backend
      await ApiClient.instance.verifyPayment(
        paymentId: paymentResult.paymentId ?? '',
        orderId: paymentResult.orderId ?? '',
        signature: paymentResult.signature ?? '',
        planType: selectedPlan,
      );

      await StorageManager.instance.setPremiumStatus(true);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Payment Successful! ${_getPlanDisplayName(selectedPlan)} unlocked.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('[PAYMENT_FLOW_ERROR] $e');
      if (mounted) setState(() => _isProcessing = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Payment cancelled or failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _getPlanDisplayName(String planKey) {
    switch (planKey) {
      case 'PLAN_BOOST_29':
        return '🚀 Profile Boost (₹29)';
      case 'PLAN_DIRECT_DM_49':
        return '⚡ Direct DM Pass (₹49)';
      case 'PLAN_AD_FREE_199':
        return '🚫 Ad-Free VIP (₹199)';
      case 'PLAN_SAFE_BRIDGE_499':
        return '🔒 Safe Bridge (₹499)';
      default:
        return 'UR Heart Pass';
    }
  }

  String _getPlanPriceLabel() {
    switch (_selectedPlanType) {
      case 'PLAN_BOOST_29':
        return '₹29';
      case 'PLAN_DIRECT_DM_49':
        return '₹49';
      case 'PLAN_AD_FREE_199':
        return '₹199';
      case 'PLAN_SAFE_BRIDGE_499':
        return '₹499';
      default:
        return '₹49';
    }
  }

  String _getPlanValidityLabel() {
    switch (_selectedPlanType) {
      case 'PLAN_BOOST_29':
        return '1 Hour 10x Discovery';
      case 'PLAN_DIRECT_DM_49':
        return '1 Hour Instant Direct DM';
      case 'PLAN_AD_FREE_199':
        return '30 Days Zero Ads';
      case 'PLAN_SAFE_BRIDGE_499':
        return 'Dual WhatsApp & Maps Unlock';
      default:
        return 'Valid 1 Hour';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
                  child: const Icon(Icons.workspace_premium, size: 28, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'UR Heart Monetization Passes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

            // 4 Distinct Standardized Plans Grid
            Row(
              children: [
                _buildPlanTile(
                  'PLAN_BOOST_29',
                  '🚀 Boost',
                  '₹29',
                  '1 Hour',
                  '10x Discovery',
                ),
                const SizedBox(width: 6),
                _buildPlanTile(
                  'PLAN_DIRECT_DM_49',
                  '⚡ Direct DM',
                  '₹49',
                  '1 Hour',
                  'Instant DM',
                ),
                const SizedBox(width: 6),
                _buildPlanTile(
                  'PLAN_AD_FREE_199',
                  '🚫 Zero Ads',
                  '₹199',
                  '30 Days',
                  'VIP Pro',
                ),
                const SizedBox(width: 6),
                _buildPlanTile(
                  'PLAN_SAFE_BRIDGE_499',
                  '🔒 Safe Bridge',
                  '₹499',
                  'Chat Lock',
                  'Maps & WA',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Detailed Highlight Box for Selected Plan
            _buildPlanDescriptionBanner(),
            const SizedBox(height: 18),

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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDescriptionBanner() {
    String title;
    String hindiSubtitle;
    String detail;
    IconData icon;
    Color accentColor;

    switch (_selectedPlanType) {
      case 'PLAN_BOOST_29':
        title = '🚀 Profile Boost (₹29)';
        hindiSubtitle = '1 Ghante ke liye 10x Jyada Discovery';
        detail = 'Apni profile ko discovery feed me top priority par layein aur 10x jyada views paayein.';
        icon = Icons.bolt;
        accentColor = Colors.amber;
        break;
      case 'PLAN_DIRECT_DM_49':
        title = '⚡ Direct DM Pass (₹49)';
        hindiSubtitle = '1 Ghante tak bina match ke direct message bhejein';
        detail = 'Kisi bhi profile ko bina mutual match ka intezar kiye turant instant direct message bhejein.';
        icon = Icons.send_rounded;
        accentColor = Colors.cyanAccent;
        break;
      case 'PLAN_AD_FREE_199':
        title = '🚫 Ad-Free VIP (₹199)';
        hindiSubtitle = '30 Din ke liye bilkul Zero Ads';
        detail = '100% Ad-Free anubhav: Koi feed cards nahi, koi 20-skip video ads nahi, bilkul smooth UI.';
        icon = Icons.block;
        accentColor = Colors.greenAccent;
        break;
      case 'PLAN_SAFE_BRIDGE_499':
        title = '🔒 Safe Bridge (₹499)';
        hindiSubtitle = '15 Messages ke baad WhatsApp aur Live Maps Unlock';
        detail = 'Dual payment safety flow: Dono users ke 15 messages aur consent ke baad secure contact unlock.';
        icon = Icons.lock_open_rounded;
        accentColor = const Color(0xFFE91E63);
        break;
      default:
        title = 'UR Heart Pass';
        hindiSubtitle = 'Instant upgrade';
        detail = 'Unlock premium dating features on UR Heart.';
        icon = Icons.star;
        accentColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
                ),
                const SizedBox(height: 2),
                Text(
                  hindiSubtitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(
    String planKey,
    String title,
    String price,
    String validity,
    String subtitle,
  ) {
    final bool isSelected = _selectedPlanType == planKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPlanType = planKey),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  validity,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 7.5, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
