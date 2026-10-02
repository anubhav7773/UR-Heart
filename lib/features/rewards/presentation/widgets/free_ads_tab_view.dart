import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../controllers/growth_hub_controller.dart';
import 'night_slumber_toggle_card.dart';
import 'rewarded_placement_tile.dart';
import 'sacred_kinship_card.dart';
import 'zero_paywall_banner.dart';
import 'mindful_streak_card.dart';

/// Tab A: 100% Free Mindful Rewarded Ads View (< 190 lines)
class FreeAdsTabView extends ConsumerWidget {
  final bool isDark;
  final String? userId;

  const FreeAdsTabView({super.key, required this.isDark, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growthState = ref.watch(growthHubControllerProvider);
    final notifier = ref.read(growthHubControllerProvider.notifier);

    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final muted = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zero-Paywall Philosophy Card
          ZeroPaywallBanner(isDark: isDark),
          const SizedBox(height: 16.0),

          // Invariant 6: Suppress ad prompts if user possesses Ad-Free Sovereign Entitlement
          if (growthState.isAdFree || growthState.subscriptionTier != 'free') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: gold, size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        'SOVEREIGN SILENCE ACTIVE',
                        style: TextStyle(fontFamily: 'Serif', color: gold, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'All voluntary sponsor prompts are suppressed under your sovereign pass.',
                    style: TextStyle(color: primary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Your resources are quietly unlimited. Pure silence reigns.',
                    style: TextStyle(color: muted, fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Hero Placement: 24-Hour Mindful Streak & Boost
            MindfulStreakCard(isDark: isDark, userId: userId),

            // Placement 1: Quick Reflection (10s)
            RewardedPlacementTile(
              isDark: isDark,
              title: 'Quick Reflection (10s Sponsor)',
              durationTag: '10s',
              rewardDescription: '+10 Profile Skips / Swipes',
              icon: Icons.timer_outlined,
              buttonText: 'Watch',
              onTap: () {
                notifier.triggerRewardedAd(
                  adType: AdPlacementTypes.quickReflection,
                  userId: userId,
                  targetId: 'none',
                  context: context,
                );
              },
            ),
            const SizedBox(height: 4.0),

            // Placement 2: Deep Resonance (20s)
            RewardedPlacementTile(
              isDark: isDark,
              title: 'Deep Resonance (20s Sponsor)',
              durationTag: '20s',
              rewardDescription: '+1 Direct Letter (Send before match)',
              icon: Icons.mail_outline,
              buttonText: 'Watch',
              onTap: () {
                notifier.triggerRewardedAd(
                  adType: AdPlacementTypes.deepResonance,
                  userId: userId,
                  targetId: 'none',
                  context: context,
                );
              },
            ),
            const SizedBox(height: 4.0),

            // Placement 3: Sacred Bridge Reveal Ritual (30s)
            RewardedPlacementTile(
              isDark: isDark,
              title: 'Sacred Bridge Reveal (30s Ritual)',
              durationTag: '30s',
              rewardDescription: (growthState.whatsappProgress > 0)
                  ? '+1 Step towards contact unmasking (${growthState.whatsappProgress}/3) · Tokens: ${growthState.revealTokensCount}'
                  : 'Watch 3 videos to earn 1 Reveal Token (0/3) · Tokens: ${growthState.revealTokensCount}',
              icon: Icons.lock_open_rounded,
              buttonText: growthState.whatsappProgress >= 2 ? 'Final Ad (3/3)' : 'Watch (${growthState.whatsappProgress}/3)',
              onTap: () {
                notifier.triggerRewardedAd(
                  adType: AdPlacementTypes.whatsappReveal,
                  userId: userId,
                  targetId: growthState.activeMatchId ?? 'none',
                  context: context,
                );
              },
            ),
          ],
          const SizedBox(height: 12.0),

          // Night Sanctuary Slumber Card
          NightSlumberToggleCard(
            isDark: isDark,
            isSlumberActive: growthState.isSlumberActive,
            onChanged: (val) => notifier.toggleSlumberMode(val, context),
          ),
          const SizedBox(height: 16.0),

          // Sacred Kinship Referral Card
          SacredKinshipCard(
            isDark: isDark,
            referralCode: growthState.referralCode,
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}
