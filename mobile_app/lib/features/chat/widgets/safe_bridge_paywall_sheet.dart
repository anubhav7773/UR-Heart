import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../subscription/payment_service.dart';

class SafeBridgePaywallSheet extends StatefulWidget {
  final String matchId;
  final String partnerName;
  final int totalMessages;
  final bool initialMyWhatsapp;
  final bool initialMyLocation;
  final bool initialPartnerWhatsapp;
  final bool initialPartnerLocation;
  final bool initialMyPaid;
  final bool initialPartnerPaid;
  final bool initialIsUnlocked;
  final String? initialPartnerPhone;
  final String? initialPartnerMapsUrl;
  final VoidCallback? onStateChanged;

  const SafeBridgePaywallSheet({
    super.key,
    required this.matchId,
    this.partnerName = 'Matched User',
    this.totalMessages = 0,
    this.initialMyWhatsapp = false,
    this.initialMyLocation = false,
    this.initialPartnerWhatsapp = false,
    this.initialPartnerLocation = false,
    this.initialMyPaid = false,
    this.initialPartnerPaid = false,
    this.initialIsUnlocked = false,
    this.initialPartnerPhone,
    this.initialPartnerMapsUrl,
    this.onStateChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required String matchId,
    String partnerName = 'Matched User',
    int totalMessages = 0,
    bool initialMyWhatsapp = false,
    bool initialMyLocation = false,
    bool initialPartnerWhatsapp = false,
    bool initialPartnerLocation = false,
    bool initialMyPaid = false,
    bool initialPartnerPaid = false,
    bool initialIsUnlocked = false,
    String? initialPartnerPhone,
    String? initialPartnerMapsUrl,
    VoidCallback? onStateChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeBridgePaywallSheet(
        matchId: matchId,
        partnerName: partnerName,
        totalMessages: totalMessages,
        initialMyWhatsapp: initialMyWhatsapp,
        initialMyLocation: initialMyLocation,
        initialPartnerWhatsapp: initialPartnerWhatsapp,
        initialPartnerLocation: initialPartnerLocation,
        initialMyPaid: initialMyPaid,
        initialPartnerPaid: initialPartnerPaid,
        initialIsUnlocked: initialIsUnlocked,
        initialPartnerPhone: initialPartnerPhone,
        initialPartnerMapsUrl: initialPartnerMapsUrl,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  State<SafeBridgePaywallSheet> createState() => _SafeBridgePaywallSheetState();
}

class _SafeBridgePaywallSheetState extends State<SafeBridgePaywallSheet> {
  late int _totalMessages;
  late bool _shareWhatsapp;
  late bool _shareLocation;
  late bool _partnerWhatsapp;
  late bool _partnerLocation;
  late bool _myPaid;
  late bool _partnerPaid;
  late bool _isUnlocked;
  String? _partnerPhone;
  String? _partnerMapsUrl;

  bool _isLoading = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _totalMessages = widget.totalMessages;
    _shareWhatsapp = widget.initialMyWhatsapp;
    _shareLocation = widget.initialMyLocation;
    _partnerWhatsapp = widget.initialPartnerWhatsapp;
    _partnerLocation = widget.initialPartnerLocation;
    _myPaid = widget.initialMyPaid;
    _partnerPaid = widget.initialPartnerPaid;
    _isUnlocked = widget.initialIsUnlocked;
    _partnerPhone = widget.initialPartnerPhone;
    _partnerMapsUrl = widget.initialPartnerMapsUrl;

    _refreshBridgeStatus();
  }

  Future<void> _refreshBridgeStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.getBridgeStatus(widget.matchId);
      final data = res.data?['data'];
      if (data is Map && mounted) {
        setState(() {
          _totalMessages = data['total_messages'] ?? _totalMessages;
          _shareWhatsapp = data['my_whatsapp_consent'] ?? _shareWhatsapp;
          _shareLocation = data['my_location_consent'] ?? _shareLocation;
          _partnerWhatsapp = data['partner_whatsapp_consent'] ?? _partnerWhatsapp;
          _partnerLocation = data['partner_location_consent'] ?? _partnerLocation;
          _myPaid = data['my_payment_done'] ?? _myPaid;
          _partnerPaid = data['partner_payment_done'] ?? _partnerPaid;
          _isUnlocked = data['is_fully_unlocked'] ?? _isUnlocked;
          _partnerPhone = data['partner_phone'] ?? _partnerPhone;
          _partnerMapsUrl = data['partner_maps_url'] ?? _partnerMapsUrl;
        });
        widget.onStateChanged?.call();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConsent() async {
    if (_totalMessages < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('15 messages complete hone ke baad Safe Share unlock hoga (Current: $_totalMessages/15)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.submitChatConsent(
        matchId: widget.matchId,
        shareWhatsapp: _shareWhatsapp,
        shareLocation: _shareLocation,
      );
      final data = res.data?['data'];
      if (data is Map && mounted) {
        setState(() {
          _isUnlocked = data['is_fully_unlocked'] ?? data['whatsapp_unlocked'] ?? false;
          _partnerPhone = data['partner_phone'];
          _partnerMapsUrl = data['partner_maps_url'];
          _myPaid = data['my_payment_done'] ?? _myPaid;
          _partnerPaid = data['partner_payment_done'] ?? _partnerPaid;
        });
        widget.onStateChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consent updated successfully! 🤝'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayment() async {
    if (_totalMessages < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone locked: Reach 15 messages first ($_totalMessages/15)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPaying = true);

    try {
      final bool success = await PaymentService.instance.buyProduct(
        PaymentService.skuSafeBridge499,
        matchId: widget.matchId,
      );

      if (success) {
        final res = await ApiClient.instance.submitBridgePayment(
          matchId: widget.matchId,
          paymentId: 'gplay_bridge_${DateTime.now().millisecondsSinceEpoch}',
          amount: 499.0,
        );

        final data = res.data?['data'];
        if (data is Map && mounted) {
          setState(() {
            _myPaid = true;
            _partnerPaid = data['partner_payment_done'] ?? _partnerPaid;
            _isUnlocked = data['is_fully_unlocked'] ?? false;
            _partnerPhone = data['partner_phone'];
            _partnerMapsUrl = data['partner_maps_url'];
          });
          widget.onStateChanged?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isUnlocked
                    ? '🎉 Payment Successful! Safe Bridge is now fully unlocked!'
                    : 'Payment Complete ✅ — Waiting for ${widget.partnerName} to unlock.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled or failed. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _launchWhatsApp() async {
    if (_partnerPhone == null || _partnerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp contact number unavailable.')),
      );
      return;
    }
    String cleanNumber = _partnerPhone!.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+91$cleanNumber';
    }
    final url = 'https://wa.me/${cleanNumber.replaceAll('+', '')}?text=${Uri.encodeComponent("Hi, we matched on UR-Heart! ✨")}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchMaps() async {
    if (_partnerMapsUrl == null || _partnerMapsUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps route unavailable.')),
      );
      return;
    }
    final uri = Uri.parse(_partnerMapsUrl!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Google Maps: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMilestoneReached = _totalMessages >= 15;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔒 Safe Meet & WhatsApp Bridge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct WhatsApp chat & Google Maps route unlock',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 15-Message Milestone Progress Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMilestoneReached
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMilestoneReached ? Colors.greenAccent : Colors.amber.shade700,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isMilestoneReached ? Icons.verified_rounded : Icons.lock_clock,
                        color: isMilestoneReached ? Colors.greenAccent : Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isMilestoneReached
                              ? '🎉 15 Messages Milestone Completed!'
                              : '🔒 15-Message Milestone Required',
                          style: TextStyle(
                            color: isMilestoneReached ? Colors.greenAccent : Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '$_totalMessages / 15',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_totalMessages / 15).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMilestoneReached ? Colors.greenAccent : Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMilestoneReached
                        ? 'You and ${widget.partnerName} have exchanged enough messages to request contact and navigation.'
                        : 'Safe Share unlocks automatically once you exchange at least 15 messages to prevent spam.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 1: Mutual Two-Way Consent
            const Text(
              'Step 1: Mutual Two-Way Consent 🤝',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Checkbox 1: WhatsApp
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _shareWhatsapp
                      ? Colors.greenAccent.withValues(alpha: 0.6)
                      : Colors.white12,
                ),
              ),
              child: CheckboxListTile(
                value: _shareWhatsapp,
                activeColor: Colors.greenAccent.shade700,
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text(
                  'Share WhatsApp Contact 💬',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _partnerWhatsapp
                      ? '${widget.partnerName} has consented! ✅'
                      : 'Waiting for ${widget.partnerName}\'s consent ⏳',
                  style: TextStyle(
                    color: _partnerWhatsapp ? Colors.greenAccent : Colors.grey,
                    fontSize: 11,
                  ),
                ),
                onChanged: isMilestoneReached
                    ? (val) {
                        setState(() => _shareWhatsapp = val ?? false);
                        _saveConsent();
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),

            // Checkbox 2: Location
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _shareLocation
                      ? Colors.blueAccent.withValues(alpha: 0.6)
                      : Colors.white12,
                ),
              ),
              child: CheckboxListTile(
                value: _shareLocation,
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text(
                  'Share Turn-by-Turn Route on Google Maps 📍',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _partnerLocation
                      ? '${widget.partnerName} has consented! ✅'
                      : 'Waiting for ${widget.partnerName}\'s consent ⏳',
                  style: TextStyle(
                    color: _partnerLocation ? Colors.lightBlueAccent : Colors.grey,
                    fontSize: 11,
                  ),
                ),
                onChanged: isMilestoneReached
                    ? (val) {
                        setState(() => _shareLocation = val ?? false);
                        _saveConsent();
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 18),

            // Step 2: Dual ₹499 Paywall Card
            const Text(
              'Step 2: Dual ₹499 Safe Meet Access 💳',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹499 One-Time Bridge Fee',
                        style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Both Users Pay',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To verify genuine romantic intent & ensure physical safety, both matches complete a ₹499 one-time unlock payment.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 14),

                  // Live Status Pills
                  Row(
                    children: [
                      // User Status
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _myPaid
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _myPaid ? Colors.greenAccent : Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Aapka Status', style: TextStyle(fontSize: 10, color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text(
                                _myPaid ? 'Paid ✅' : 'Pending ₹499 ⏳',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _myPaid ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Partner Status
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _partnerPaid
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _partnerPaid ? Colors.greenAccent : Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${widget.partnerName} Status', style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                _partnerPaid ? 'Paid ✅' : 'Pending ⏳',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _partnerPaid ? Colors.greenAccent : Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pay / Status Action Button
                  if (!_myPaid)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isPaying || !isMilestoneReached) ? null : _handlePayment,
                        icon: _isPaying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.flash_on, size: 18),
                        label: Text(
                          _isPaying
                              ? 'Processing Payment...'
                              : (isMilestoneReached ? 'Pay ₹499 to Unlock Bridge ⚡' : '🔒 Locked (Need 15 Msgs)'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else if (!_partnerPaid)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: Colors.tealAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment Complete ✅ — Waiting for ${widget.partnerName} to unlock.',
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Live Unlocked UI
            if (_isUnlocked || (_myPaid && _partnerPaid && (_shareWhatsapp || _shareLocation) && (_partnerWhatsapp || _partnerLocation))) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_open_rounded, color: Colors.greenAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          '🎉 Safe Bridge Fully Unlocked!',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Both mutual consent and dual ₹499 payments are verified. You can now chat directly on WhatsApp and navigate via Google Maps.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                    const SizedBox(height: 14),

                    if (_partnerPhone != null && _partnerPhone!.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _launchWhatsApp,
                          icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                          label: Text(
                            '💬 Open WhatsApp (${_partnerPhone!})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                    if (_partnerMapsUrl != null && _partnerMapsUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _launchMaps,
                          icon: const Icon(Icons.directions, size: 18, color: Colors.white),
                          label: const Text(
                            '📍 Open Route in Google Maps',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
