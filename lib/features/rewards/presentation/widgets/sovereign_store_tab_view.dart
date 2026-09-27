import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../controllers/growth_hub_controller.dart';

/// Tab B: Sovereign Store & Web Uplink (< 220 lines)
class SovereignStoreTabView extends ConsumerWidget {
  final bool isDark;

  const SovereignStoreTabView({super.key, required this.isDark});

  static const String storeWebUrl = 'https://urheart.asiverticals.me/store';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final terracotta = isDark ? DarkSanctuaryTokens.accentTerracotta : LightSanctuaryTokens.accentTerracotta;
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
                  'Pure Silence · Infinite Resonances · 100% Ad-Free',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: primaryText),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'Unlimited card discovery, 5 weekly direct letters, instantaneous contact unmasking, and global passport access.',
                  style: TextStyle(fontSize: 12.0, color: subText, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Web Store Uplink Banner (10% Bonus / Sovereign Discount)
          InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () => launchUrl(Uri.parse(storeWebUrl), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: terracotta.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: terracotta.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.language, color: terracotta, size: 20.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sanctuary Web Store (10% Extra Passes)',
                            style: TextStyle(color: terracotta, fontSize: 13.0, fontWeight: FontWeight.bold)),
                        Text('Visit urheart.asiverticals.me/store for web checkout via UPI/Cards.',
                            style: TextStyle(color: subText, fontSize: 11.0)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 12.0, color: terracotta),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18.0),

          // Subscriptions Group
          Text('SOVEREIGN PASSES', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: subText, letterSpacing: 0.8)),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: '1-Week Sovereign Sprint', priceText: '\$4.99 / ₹49', badgeText: 'Popular', productId: 'urheart_pass_weekly'),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: '1-Month Sovereign Pass', priceText: '\$14.99 / ₹149', badgeText: 'Most Mindful', productId: 'urheart_pass_monthly', isHighlighted: true),
          const SizedBox(height: 10.0),
          _buildSubscriptionTile(context, ref, title: 'Lifetime Sovereign Crest', priceText: '\$59.99 / ₹799', badgeText: 'One-Time Forever', productId: 'urheart_pass_lifetime'),
          const SizedBox(height: 22.0),

          // A La Carte Micro-Store
          Text('A LA CARTE MICRO-PACKS', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: subText, letterSpacing: 0.8)),
          const SizedBox(height: 10.0),
          _buildMicroPackRow(ref, 'Instant Contact Key', 'Skip 3-ad ritual instantly', '\$1.49 / ₹29', 'urheart_key_instant_contact', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(ref, '3 Direct Letters Pack', 'Reach their private inbox', '\$1.99 / ₹49', 'urheart_pack_direct_letters', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(ref, '48h Global Passport', 'Teleport to any global city', '\$2.99 / ₹79', 'urheart_pack_global_passport', surface, primaryText, subText, pine),
          const SizedBox(height: 18.0),

          // Google Play Policy Restore Purchases Link
          Center(
            child: TextButton(
              onPressed: () => ref.read(growthHubControllerProvider.notifier).restorePurchases(context),
              child: Text('Restore Purchases (Google Play)',
                  style: TextStyle(color: subText, fontSize: 12.0, decoration: TextDecoration.underline)),
            ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: primary)),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isHighlighted ? gold : pine, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            onPressed: () => ref.read(growthHubControllerProvider.notifier).purchasePackage(productId, context),
            child: const Text('Unlock', style: TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroPackRow(WidgetRef ref, String title, String subtitle, String price, String productId, Color surface, Color primary, Color sub, Color pine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0, color: primary)),
            Text(subtitle, style: TextStyle(fontSize: 11.0, color: sub)),
          ]),
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
