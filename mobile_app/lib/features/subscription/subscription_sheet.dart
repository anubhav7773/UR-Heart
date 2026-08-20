import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../../core/theme/app_theme.dart';
import 'payment_service.dart';

class SachetPlanItem {
  final String id;
  final String title;
  final int price;
  final String validity;
  final String tag;
  final String hindiSubtitle;
  final String description;
  final IconData icon;

  const SachetPlanItem({
    required this.id,
    required this.title,
    required this.price,
    required this.validity,
    required this.tag,
    required this.hindiSubtitle,
    required this.description,
    required this.icon,
  });
}

final List<SachetPlanItem> availablePlans = [
  const SachetPlanItem(
    id: 'boost',
    title: 'Profile Boost',
    price: 29,
    validity: '1 Hour',
    tag: '10x Discovery',
    hindiSubtitle: '1 Ghante ke liye 10x Jyada Discovery',
    description: 'Apni profile ko discovery feed me top priority par layein aur 10x jyada views paayein.',
    icon: Icons.rocket_launch,
  ),
  const SachetPlanItem(
    id: 'direct_dm',
    title: 'Direct DM Pass',
    price: 49,
    validity: '1 Hour',
    tag: 'Instant DM',
    hindiSubtitle: '1 Ghante tak bina match ke direct message bhejein',
    description: '1 Ghante tak bina match ke direct message bhejein kisi bhi profile ko.',
    icon: Icons.flash_on,
  ),
  const SachetPlanItem(
    id: 'zero_ads',
    title: 'Zero Ads VIP Pass',
    price: 199,
    validity: '30 Days',
    tag: 'VIP Pro',
    hindiSubtitle: '30 Din ke liye bilkul Zero Ads',
    description: '30 Dinon tak bina kisi ads ke full app smoothly use karein.',
    icon: Icons.block,
  ),
  const SachetPlanItem(
    id: 'safe_bridge',
    title: 'Safe Meet & WhatsApp Bridge',
    price: 499,
    validity: 'Chat Lock',
    tag: 'Maps & WA',
    hindiSubtitle: '15 Messages ke baad WhatsApp aur Live Maps Unlock',
    description: 'Direct WhatsApp chat & Google Maps turn-by-turn route unlock karein.',
    icon: Icons.lock_outline,
  ),
];

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
  late SachetPlanItem _selectedPlan;

  String? _activePassBadge;
  bool _hasActivePass = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = _resolveInitialPlan(widget.initialPlanType);
    _fetchActivePassStatus();
  }

  SachetPlanItem _resolveInitialPlan(String? planKey) {
    if (planKey == null) return availablePlans[1]; // default to direct_dm
    final key = planKey.toLowerCase().trim();
    if (key.contains('boost')) {
      return availablePlans[0];
    } else if (key.contains('dm') || key.contains('direct') || key.contains('49')) {
      return availablePlans[1];
    } else if (key.contains('ad') || key.contains('zero') || key.contains('199')) {
      return availablePlans[2];
    } else if (key.contains('bridge') || key.contains('safe') || key.contains('499')) {
      return availablePlans[3];
    }
    return availablePlans[1];
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
      // Non-blocking status lookup
    }
  }

  Future<void> _initiateSachetPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final selectedPlan = _selectedPlan;

    // STEP 1: Pop the bottom modal sheet cleanly FIRST
    navigator.pop(true);

    // STEP 2: Crucial delay (250ms) to allow Flutter modal transition to fully unmount
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      // STEP 3: Create order on backend (Phase 1 endpoint)
      final orderResponse = await ApiClient.instance.createSachetOrder(
        planType: selectedPlan.id,
      );

      final dynamic rawData = orderResponse.data?['data'] ?? orderResponse.data;
      if (rawData == null) {
        throw Exception('Failed to generate order from server');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
      final String orderId = (data['order_id'] ?? '').toString();
      final int amountInPaise = data['amount_in_paise'] != null
          ? (data['amount_in_paise'] as num).toInt()
          : (selectedPlan.price * 100);
      final String keyId = (data['razorpay_key_id'] ?? 'rzp_test_sample').toString();
      final String description = (data['description'] ?? 'UR-Heart - ${selectedPlan.title}').toString();

      final currentUser = FirebaseAuth.instance.currentUser;

      // STEP 4: Launch Native Razorpay via persistent Singleton
      final PaymentSuccessResponse paymentResult = await PaymentService().openCheckout(
        orderId: orderId,
        amountInPaise: amountInPaise,
        razorpayKeyId: keyId,
        description: description,
        userEmail: currentUser?.email,
        userPhone: currentUser?.phoneNumber,
      );

      // STEP 5: Verify Payment on Backend
      await ApiClient.instance.verifyPayment(
        paymentId: paymentResult.paymentId ?? '',
        orderId: paymentResult.orderId ?? '',
        signature: paymentResult.signature ?? '',
        planType: selectedPlan.id,
      );

      await StorageManager.instance.setPremiumStatus(true);

      // STEP 6: Success feedback and activation
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          content: Text('🎉 ${selectedPlan.title} activated successfully!'),
        ),
      );
    } catch (e) {
      debugPrint('[CHECKOUT_FLOW_FAILED] $e');
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Payment cancelled or failed. Please try again.'),
        ),
      );
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

            // 4 Distinct Standardized Plans Grid (Tabs)
            Row(
              children: availablePlans.map((plan) {
                return _buildPlanTile(plan);
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Detailed Highlight Box for Selected Plan
            _buildPlanDescriptionBanner(_selectedPlan),
            const SizedBox(height: 18),

            // Pay Action Button (pure payment trigger, NO secondary modals)
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
                    : 'Pay ₹${_selectedPlan.price} via UPI (${_selectedPlan.validity} ${_selectedPlan.title})',
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

  Widget _buildPlanDescriptionBanner(SachetPlanItem plan) {
    Color accentColor;
    switch (plan.id) {
      case 'boost':
        accentColor = Colors.amber;
        break;
      case 'direct_dm':
        accentColor = Colors.cyanAccent;
        break;
      case 'zero_ads':
        accentColor = Colors.greenAccent;
        break;
      case 'safe_bridge':
        accentColor = const Color(0xFFE91E63);
        break;
      default:
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
            child: Icon(plan.icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.title} (₹${plan.price})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.hindiSubtitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(SachetPlanItem plan) {
    final bool isSelected = _selectedPlan.id == plan.id;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: InkWell(
          // CRITICAL: Tapping card ONLY updates local selectedPlan state
          onTap: () {
            setState(() {
              _selectedPlan = plan;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
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
                Icon(plan.icon, size: 16, color: isSelected ? AppTheme.primaryColor : Colors.white70),
                const SizedBox(height: 4),
                Text(
                  plan.title.replaceFirst(' Pass', ''),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  '₹${plan.price}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.validity,
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
                  plan.tag,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 7.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
