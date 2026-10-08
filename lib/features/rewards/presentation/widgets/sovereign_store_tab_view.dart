import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../controllers/growth_hub_controller.dart';

/// Tab B: Sovereign Store (< 220 lines)
class SovereignStoreTabView extends ConsumerWidget {
  final bool isDark;

  const SovereignStoreTabView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sovereign Perks Highlight Card
          Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20.0),
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
                      'SANCTUARY SOVEREIGN PRIVILEGE',
                      style: TextStyle(fontFamily: 'Serif', color: gold, fontSize: 13.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Text(
                  'Pure Silence · Focused Resonances · 100% Ad-Free',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: primaryText),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'Curated card discovery, priority counsel, instantaneous contact unmasking, and 100% ad-free experience.',
                  style: TextStyle(fontSize: 12.0, color: subText, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Sovereign In-App Security Banner (Google Play Compliant)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: pine.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: pine.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: pine, size: 22.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sovereign Verified Sanctuary',
                          style: TextStyle(color: primaryText, fontSize: 13.0, fontWeight: FontWeight.bold)),
                      Text('Official Google Play In-App Billing · Instant activation & encrypted pass sync.',
                          style: TextStyle(color: subText, fontSize: 11.0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18.0),

          // Subscriptions Group
          Text('SOVEREIGN PASSES', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: subText, letterSpacing: 0.8)),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: '1-Week Sovereign Sprint', priceText: '₹49 (100 Swipes)', badgeText: '7 Days Access', productId: 'urheart_pass_weekly'),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: '1-Month Sovereign Pass', priceText: '₹149 (500 Swipes)', badgeText: '30 Days Access', productId: 'urheart_pass_monthly', isHighlighted: true),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: '1-Year Sovereign Pass', priceText: '₹1,499', badgeText: '365 Days Access', productId: 'urheart_pass_lifetime'),
          const SizedBox(height: 22.0),

          // A La Carte Micro-Store
          Text('A LA CARTE MICRO-PACKS', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: subText, letterSpacing: 0.8)),
          const SizedBox(height: 10.0),
          _buildMicroPackRow(context, ref, 'Instant Contact Key', 'Fast-track reveal with mutual consent', '₹29', 'urheart_key_instant_contact', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(context, ref, '3 Direct Letters Pack', 'Reach their private inbox', '₹49', 'urheart_pack_direct_letters', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(context, ref, '24h Global Passport', 'Teleport to any global city for 24h', '₹99', 'urheart_pack_global_passport', surface, primaryText, subText, pine),
          const SizedBox(height: 18.0),

          // Google Play Policy Restore Purchases & Sovereign Sync
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => ref.read(growthHubControllerProvider.notifier).restorePurchases(context),
                icon: Icon(Icons.restore_rounded, size: 14.0, color: subText),
                label: Text('Restore Purchases',
                    style: TextStyle(color: subText, fontSize: 12.0, decoration: TextDecoration.underline)),
              ),
              const SizedBox(width: 16.0),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(growthHubControllerProvider.notifier).syncUserData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✨ Sovereign entitlement synchronized with Sanctuary server.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.sync_rounded, size: 14.0, color: gold),
                label: Text('Sync Sovereign Status',
                    style: TextStyle(color: gold, fontSize: 12.0, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context, WidgetRef ref, {required String title, required String priceText, required String badgeText, required String productId, bool isHighlighted = false}) {
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: isHighlighted ? gold : surface, width: isHighlighted ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(color: (isHighlighted ? gold : pine).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6.0)),
                      child: Text(badgeText, style: TextStyle(color: isHighlighted ? gold : pine, fontSize: 10.0, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(priceText, style: TextStyle(fontSize: 13.0, color: primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isHighlighted ? gold : pine, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            onPressed: () => ref.read(growthHubControllerProvider.notifier).purchasePackage(productId, context),
            child: const Text('Unlock', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroPackRow(BuildContext context, WidgetRef ref, String title, String subtitle, String price, String productId, Color surface, Color primary, Color sub, Color pine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14.0)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0, color: primary)),
                Text(subtitle, style: TextStyle(fontSize: 11.0, color: sub)),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: pine.withValues(alpha: 0.12), elevation: 0, visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            onPressed: () => ref.read(growthHubControllerProvider.notifier).purchaseMicroPack(productId),
            child: Text(price, style: TextStyle(color: pine, fontSize: 12.0, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

