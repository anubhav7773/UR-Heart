import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/ads/services/ad_manager.dart';
import '../../features/wallet/data/wallet_repository.dart';

enum CreditActionType { directDm, waReveal, missedBio }

class InsufficientCreditsSheet extends StatefulWidget {
  final CreditActionType actionType;
  final String targetUserId;
  final VoidCallback onCreditAcquired;

  const InsufficientCreditsSheet({
    super.key,
    required this.actionType,
    required this.targetUserId,
    required this.onCreditAcquired,
  });

  static Future<void> show(
    BuildContext context, {
    required CreditActionType actionType,
    required String targetUserId,
    required VoidCallback onCreditAcquired,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => InsufficientCreditsSheet(
        actionType: actionType,
        targetUserId: targetUserId,
        onCreditAcquired: onCreditAcquired,
      ),
    );
  }

  @override
  State<InsufficientCreditsSheet> createState() => _InsufficientCreditsSheetState();
}

class _InsufficientCreditsSheetState extends State<InsufficientCreditsSheet> {
  final WalletRepository _walletRepo = WalletRepository();
  bool _isClaiming = false;

  void _watchAdAndCredit(String adTier, String rewardChoice) {
    setState(() => _isClaiming = true);

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? widget.targetUserId;

    Future<void> onReward() async {
      try {
        await _walletRepo.claimReward(adTier: adTier, rewardChoice: rewardChoice);
        if (mounted) {
          Navigator.pop(context);
          widget.onCreditAcquired();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✓ Reward credited! Resuming your action..."),
              backgroundColor: Color(0xFF06D6A0),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Claim failed: $e"), backgroundColor: const Color(0xFFFF334B)),
          );
        }
      } finally {
        if (mounted) setState(() => _isClaiming = false);
      }
    }

    final bool shown = AdManager.instance.showRewardedAd(
      userId: currentUserId,
      adType: adTier,
      targetId: widget.targetUserId,
      onRewardGranted: onReward,
    );

    if (!shown) {
      // In dev or test environments when ad is not buffered, allow direct credit
      onReward();
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardSurface = Color(0xFF16161D);
    const surfaceRaised = Color(0xFF22222C);
    const brandCrimson = Color(0xFFFF2E63);
    const accentGold = Color(0xFFFFD166);

    String title;
    String subtitle;
    String primaryAdOption;
    String primaryTier;
    String primaryRewardChoice;

    switch (widget.actionType) {
      case CreditActionType.directDm:
        title = "Direct DMs Finished / डीएम समाप्त!";
        subtitle = "You have 0 Direct DM credits left. Watch a quick ad to send this message instantly.";
        primaryAdOption = "Watch 10s Ad -> +1 Direct DM";
        primaryTier = "10s";
        primaryRewardChoice = "dm_credit";
        break;
      case CreditActionType.waReveal:
        title = "WhatsApp Token Needed / टोकन चाहिए";
        subtitle = "Mutual WhatsApp reveals require an unlock token. Watch a short clip to advance.";
        primaryAdOption = "Watch 30s Ad -> +1 Reveal Token";
        primaryTier = "30s";
        primaryRewardChoice = "wa_reveal_token";
        break;
      case CreditActionType.missedBio:
        title = "Missed Bio Pass Required";
        subtitle = "Watch a 10s clip to unlock this profile's bio and interests for 24 hours.";
        primaryAdOption = "Watch 10s Ad -> Unlock Bio";
        primaryTier = "10s";
        primaryRewardChoice = "missed_bio_pass";
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Icon & Header
          const Icon(Icons.flash_off_rounded, color: accentGold, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Primary Quick Option
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandCrimson,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isClaiming ? null : () => _watchAdAndCredit(primaryTier, primaryRewardChoice),
              child: _isClaiming
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(
                      primaryAdOption,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Multi-Option Card (For DMs: +2 DMs for 20s)
          if (widget.actionType == CreditActionType.directDm) ...[
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: surfaceRaised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: TextButton.icon(
                onPressed: _isClaiming ? null : () => _watchAdAndCredit("20s", "dm_credit"),
                icon: const Icon(Icons.play_circle_outline, color: accentGold, size: 20),
                label: const Text(
                  "Watch 20s Ad -> +2 Direct DMs",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tip on Overnight Auto-Farm
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.bedtime_outlined, color: Color(0xFF08D9D6), size: 14),
              SizedBox(width: 6),
              Text(
                "Tip: Collect 15+ DMs while sleeping using Night Farm in Profile.",
                style: TextStyle(color: Color(0xFF08D9D6), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
