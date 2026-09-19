import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

class ReferralShareCard extends StatefulWidget {
  const ReferralShareCard({super.key});

  @override
  State<ReferralShareCard> createState() => _ReferralShareCardState();
}

class _ReferralShareCardState extends State<ReferralShareCard> {
  String _referralCode = "LOADING...";
  int _totalInvites = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReferralCode();
  }

  Future<void> _fetchReferralCode() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      final res = await dio.get(
        '/api/v1/referral/my-code',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted && res.statusCode == 200) {
        setState(() {
          _referralCode = res.data['referral_code'] ?? "UR-HEART";
          _totalInvites = res.data['total_invites'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    HapticFeedback.mediumImpact();
    final String shareMessage =
        "Hey! Check out UR-Heart — India's verified romantic dating app. ❤️\n\n"
        "Sign up using my invite code *$_referralCode* and we BOTH get 5 Direct DMs + 2 WhatsApp Number Reveals for FREE (No ads needed)!\n\n"
        "Download now: https://urheart.asiverticals.me/join?ref=$_referralCode";

    final uri = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(shareMessage)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to general intent
      Clipboard.setData(ClipboardData(text: shareMessage));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✓ Invite link copied to clipboard! Share on WhatsApp.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1728), Color(0xFF13131A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF2E63).withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2E63).withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2E63).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF2E63).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFFF2E63), size: 14),
                    SizedBox(width: 6),
                    Text(
                      "ZERO-AD REWARDS",
                      style: TextStyle(color: Color(0xFFFF2E63), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Text(
                "$_totalInvites Friends Joined",
                style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const Text(
            "Invite Friends, Unlock Everything",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            "Share your invite link with friends. When they sign up, both of you get 5 Direct DMs & 2 WhatsApp Reveals free without watching ads.",
            style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),

          // Code Display Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("YOUR INVITE CODE", style: TextStyle(color: Color(0xFF636375), fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _referralCode,
                      style: const TextStyle(color: Color(0xFFFFD166), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: _referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✓ Referral code copied!"), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1-Tap WhatsApp Share Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              icon: const Icon(Icons.share_rounded, color: Colors.black, size: 18),
              label: const Text(
                "Share on WhatsApp (+5 DMs Each)",
                style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading ? null : _shareOnWhatsApp,
            ),
          ),
        ],
      ),
    );
  }
}
