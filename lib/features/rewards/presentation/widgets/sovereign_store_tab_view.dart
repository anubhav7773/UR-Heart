import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            onTap: () => ref.read(growthHubControllerProvider.notifier).openWebStore(null, context),
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
          _buildMicroPackRow(context, ref, 'Instant Contact Key', 'Skip 3-ad ritual instantly', '\$1.49 / ₹29', 'urheart_key_instant_contact', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(context, ref, '3 Direct Letters Pack', 'Reach their private inbox', '\$1.99 / ₹49', 'urheart_pack_direct_letters', surface, primaryText, subText, pine),
          const SizedBox(height: 8.0),
          _buildMicroPackRow(context, ref, '48h Global Passport', 'Teleport to any global city', '\$2.99 / ₹79', 'urheart_pack_global_passport', surface, primaryText, subText, pine),
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

  void _showCheckoutModal(
    BuildContext context,
    WidgetRef ref, {
    required String productId,
    required String title,
    required String priceText,
  }) {
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primary = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final sub = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            border: Border.all(color: gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sub.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: gold, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sovereign Access Gateway',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Unlock $title ($priceText). Choose your preferred checkout channel.',
                style: TextStyle(fontSize: 13, color: sub, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Option 1: Web Sanctuary Checkout (Recommended)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(growthHubControllerProvider.notifier).openWebStore(productId, context);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pine.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pine, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: pine.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.language_rounded, color: gold, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Web Sanctuary Store',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: gold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+10% BONUS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Instant checkout with UPI (GPay/PhonePe), Cards, & NetBanking at urheart.asiverticals.me/store.',
                              style: TextStyle(fontSize: 11.5, color: sub),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: Google Play Billing
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (productId.startsWith('urheart_pass_')) {
                    ref.read(growthHubControllerProvider.notifier).purchasePackage(productId, context);
                  } else {
                    ref.read(growthHubControllerProvider.notifier).purchaseMicroPack(productId);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sub.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sub.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.shop_rounded, color: primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Google Play In-App Billing',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Standard in-app billing through your connected Google Play account.',
                              style: TextStyle(fontSize: 11.5, color: sub),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: sub),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
            onPressed: () => _showCheckoutModal(context, ref, productId: productId, title: title, priceText: priceText),
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
            onPressed: () => _showCheckoutModal(context, ref, productId: productId, title: title, priceText: price),
            child: Text(price, style: TextStyle(color: pine, fontSize: 12.0, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

