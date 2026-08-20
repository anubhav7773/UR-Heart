import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/security/storage_manager.dart';
import '../subscription/payment_service.dart';

class ManageSubscriptionsSheet extends StatefulWidget {
  const ManageSubscriptionsSheet({super.key});

  @override
  State<ManageSubscriptionsSheet> createState() => _ManageSubscriptionsSheetState();
}

class _ManageSubscriptionsSheetState extends State<ManageSubscriptionsSheet> {
  bool _isLoading = true;
  Map<String, dynamic> _passData = {};

  @override
  void initState() {
    super.initState();
    _fetchActivePasses();
  }

  Future<void> _fetchActivePasses() async {
    try {
      final res = await ApiClient.instance.dio.get('/payments/active-pass');
      final dynamic raw = res.data?['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _passData = (raw != null) ? Map<String, dynamic>.from(raw) : {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchasePass(String planType, int price, String title) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop(); // Close sheet before opening native checkout
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      final res = await ApiClient.instance.createSachetOrder(planType: planType);
      final dynamic raw = res.data?['data'] ?? res.data;
      if (raw == null) {
        throw Exception('Failed to generate order from server');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      final String orderId = (data['order_id'] ?? '').toString();
      final int amountInPaise = data['amount_in_paise'] != null
          ? (data['amount_in_paise'] as num).toInt()
          : (price * 100);
      final String keyId = (data['razorpay_key_id'] ?? 'rzp_test_sample').toString();
      final String description = (data['description'] ?? title).toString();

      final result = await PaymentService.instance.openCheckout(
        orderId: orderId,
        amountInPaise: amountInPaise,
        razorpayKeyId: keyId,
        description: description,
      );

      await ApiClient.instance.verifyPayment(
        paymentId: result.paymentId ?? '',
        orderId: result.orderId ?? '',
        signature: result.signature ?? '',
        planType: planType,
      );

      await StorageManager.instance.setPremiumStatus(true);

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('🎉 $title activated successfully!'),
        ),
      );
    } catch (e) {
      debugPrint('[PURCHASE_FAIL] $e');
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
    final bool isBoosted = _passData['is_boosted'] == true;
    final bool hasDirectDm = (_passData['has_direct_dm'] == true) || (_passData['is_direct_dm_active'] == true);
    final bool isAdFree = _passData['is_ad_free'] == true;
    final bool hasSafeBridge = _passData['has_safe_bridge'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFFFF3366))))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage UR-Heart Passes',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'View remaining time, active perks, or extend your subscriptions.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // 1. Profile Boost
                  _buildPassCard(
                    title: 'Profile Boost',
                    price: 29,
                    planType: 'boost',
                    icon: Icons.rocket_launch,
                    iconColor: const Color(0xFFFF5252),
                    isActive: isBoosted,
                    remainingText: _passData['boost_remaining'] ?? (isBoosted ? '${_passData['boost_remaining_minutes'] ?? 60}m left' : '1 Hour • 10x Discovery'),
                    description: 'Ranks your profile top in discovery feed.',
                  ),

                  // 2. Direct DM Pass
                  _buildPassCard(
                    title: 'Direct DM Pass',
                    price: 49,
                    planType: 'direct_dm',
                    icon: Icons.flash_on,
                    iconColor: const Color(0xFFFFD600),
                    isActive: hasDirectDm,
                    remainingText: _passData['direct_dm_remaining'] ?? (hasDirectDm ? '${_passData['direct_dm_remaining_minutes'] ?? 60}m left' : '1 Hour • Unlimited Direct DMs'),
                    description: 'Message anyone without waiting for mutual match.',
                  ),

                  // 3. Zero Ads VIP Pass
                  _buildPassCard(
                    title: 'Zero Ads VIP Pass',
                    price: 199,
                    planType: 'zero_ads',
                    icon: Icons.block,
                    iconColor: const Color(0xFF00E676),
                    isActive: isAdFree,
                    remainingText: _passData['ad_free_remaining'] ?? '30 Days • Completely Ad-Free',
                    description: 'Zero popup video ads across the entire app.',
                  ),

                  // 4. Safe Meet & WhatsApp Bridge
                  _buildPassCard(
                    title: 'Safe Meet & WhatsApp Bridge',
                    price: 499,
                    planType: 'safe_bridge',
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF40C4FF),
                    isActive: hasSafeBridge,
                    remainingText: _passData['safe_bridge_remaining'] ?? 'Chat Lock • WA & Maps',
                    description: 'Mutual consent bridge for verified public meetups.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildPassCard({
    required String title,
    required int price,
    required String planType,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required String remainingText,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? iconColor.withValues(alpha: 0.5) : Colors.white10,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  remainingText,
                  style: TextStyle(
                    color: isActive ? iconColor : Colors.white60,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.white12 : const Color(0xFFFF3366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: () => _purchasePass(planType, price, title),
            child: Text(
              isActive ? 'Extend' : '₹$price',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
