import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../subscription/payment_service.dart';

class ManageSubscriptionsSheet extends StatefulWidget {
  const ManageSubscriptionsSheet({super.key});

  @override
  State<ManageSubscriptionsSheet> createState() => _ManageSubscriptionsSheetState();
}

class _ManageSubscriptionsSheetState extends State<ManageSubscriptionsSheet> {
  bool _isLoading = true;
  Map<String, dynamic> _passData = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchActivePasses();
    _startPeriodicCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isLoading) {
        setState(() {}); // Re-render live countdowns second-by-second
      }
    });
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

  String _formatRemainingTime(String? isoExpiry, String fallbackText) {
    if (isoExpiry == null) return fallbackText;
    final expiry = DateTime.tryParse(isoExpiry)?.toUtc();
    if (expiry == null) return fallbackText;

    final now = DateTime.now().toUtc();
    final difference = expiry.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      return 'Expired';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m left';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s left';
    } else {
      return '${minutes}m ${seconds}s left';
    }
  }

  bool _isPassActive(String? isoExpiry) {
    if (isoExpiry == null) return false;
    final expiry = DateTime.tryParse(isoExpiry)?.toUtc();
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now().toUtc());
  }

  Future<void> _handlePassPurchaseOrExtend({
    required String planType,
    required int price,
    required String title,
  }) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Close bottom modal cleanly before native Google Play billing opens
    nav.pop();
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      final bool success = await PaymentService.instance.buyProduct(planType);

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('🎉 $title updated successfully!'),
          ),
        );
        _fetchActivePasses();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Payment cancelled or failed. Please try again.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RENEWAL_CANCELLED_OR_FAILED] $e');
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
    final bool boostActive = _isPassActive(_passData['boost_expires_at']);
    final bool dmActive = _isPassActive(_passData['direct_dm_expires_at']);
    final bool adsActive = _isPassActive(_passData['ad_free_expires_at']);
    final bool bridgeActive = _passData['has_safe_bridge'] == true;

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
                    'Active Subscriptions & Passes',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Live real-time status and instant renewal.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // 1. Profile Boost Card
                  _buildLivePassCard(
                    title: 'Profile Boost',
                    price: 29,
                    planType: 'boost',
                    icon: Icons.rocket_launch,
                    iconColor: const Color(0xFFFF5252),
                    isActive: boostActive,
                    timeLabel: _formatRemainingTime(_passData['boost_expires_at'], '1 Hour • 10x Discovery'),
                    description: 'Puts your card first in the discovery deck.',
                  ),

                  // 2. Direct DM Pass Card
                  _buildLivePassCard(
                    title: 'Direct DM Pass',
                    price: 49,
                    planType: 'direct_dm',
                    icon: Icons.flash_on,
                    iconColor: const Color(0xFFFFD600),
                    isActive: dmActive,
                    timeLabel: _formatRemainingTime(_passData['direct_dm_expires_at'], '1 Hour • Instant DMs'),
                    description: 'Direct messaging without mutual swipe waiting.',
                  ),

                  // 3. Zero Ads VIP Pass Card
                  _buildLivePassCard(
                    title: 'Zero Ads VIP Pass',
                    price: 199,
                    planType: 'zero_ads',
                    icon: Icons.block,
                    iconColor: const Color(0xFF00E676),
                    isActive: adsActive,
                    timeLabel: _formatRemainingTime(_passData['ad_free_expires_at'], '30 Days • VIP Pro'),
                    description: 'Completely eliminates all popup and reward ads.',
                  ),

                  // 4. Safe Meet & WhatsApp Bridge Card
                  _buildLivePassCard(
                    title: 'Safe Meet & WhatsApp Bridge',
                    price: 499,
                    planType: 'safe_bridge',
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF40C4FF),
                    isActive: bridgeActive,
                    timeLabel: bridgeActive ? 'Active on Matches' : 'Chat Lock • WA & Maps',
                    description: 'Mutual consent bridge for verified public meetups.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildLivePassCard({
    required String title,
    required int price,
    required String planType,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required String timeLabel,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? iconColor.withValues(alpha: 0.6) : Colors.white10,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
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
                  timeLabel,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: () => _handlePassPurchaseOrExtend(
              planType: planType,
              price: price,
              title: title,
            ),
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
