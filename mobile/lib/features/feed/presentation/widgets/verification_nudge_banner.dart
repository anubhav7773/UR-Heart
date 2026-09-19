import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../kyc/presentation/video_kyc_screen.dart';

class VerificationNudgeBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const VerificationNudgeBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161D26), Color(0xFF0E131A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00B2FF).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B2FF).withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00B2FF).withOpacity(0.12),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF00B2FF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Get Verified for 3x Matches",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  "A quick 3-second selfie check gives your profile a Blue Tick & top radar priority.",
                  style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B2FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VideoKycScreen()),
              );
            },
            child: const Text(
              "Verify",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
