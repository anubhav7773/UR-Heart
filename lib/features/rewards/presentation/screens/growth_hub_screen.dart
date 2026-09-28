import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/ad_reward_models.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../controllers/growth_hub_controller.dart';
import '../services/slumber_sensor_service.dart';
import '../widgets/free_ads_tab_view.dart';
import '../widgets/morning_harvest_modal.dart';
import '../widgets/resource_metrics_bar.dart';
import '../widgets/sovereign_store_tab_view.dart';

/// Screen 10: Growth PRO & Sovereign Vault Scaffold (< 190 lines)
class GrowthHubScreen extends ConsumerStatefulWidget {
  static const String routeName = '/growth';
  final String userId;

  const GrowthHubScreen({
    super.key,
    this.userId = '11111111-1111-1111-1111-111111111111',
  });

  @override
  ConsumerState<GrowthHubScreen> createState() => _GrowthHubScreenState();
}

class _GrowthHubScreenState extends ConsumerState<GrowthHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupSlumberSensorListener();
    Future.microtask(() {
      ref.read(growthHubControllerProvider.notifier).syncBalances(userId: widget.userId);
    });
  }

  void _setupSlumberSensorListener() {
    SlumberSensorService.instance.startMonitoring(
      onMorningPickup: () {
        if (!mounted) return;
        final isDark = ref.read(themeProvider).activeTheme == SanctuaryTheme.dark;
        showDialog<void>(
          context: context,
          builder: (ctx) => MorningHarvestModal(
            isDark: isDark,
            onClaimHarvestTapped: () {
              ref.read(growthHubControllerProvider.notifier).triggerRewardedAd(
                    adType: AdPlacementTypes.morningHarvestUnlock,
                    userId: widget.userId,
                    context: context,
                  );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    SlumberSensorService.instance.stopMonitoring();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).activeTheme == SanctuaryTheme.dark;
    final growthState = ref.watch(growthHubControllerProvider);

    final bg = isDark ? DarkSanctuaryTokens.background : LightSanctuaryTokens.background;
    final primaryText = isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final surface = isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Growth PRO · REWARDS HUB',
          style: TextStyle(fontFamily: 'Serif', fontSize: 16.0, fontWeight: FontWeight.bold, color: primaryText),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Resource Status Metrics Bar
            ResourceMetricsBar(
              isDark: isDark,
              swipesRemaining: growthState.swipesRemaining,
              directLetters: growthState.directLetters,
              isAdFree: growthState.isAdFree,
            ),
            const SizedBox(height: 10.0),

            // Mode Segmented Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                height: 44.0,
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isDark ? DarkSanctuaryTokens.surfaceCardBorder : LightSanctuaryTokens.surfaceCardBorder,
                    width: 0.8,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: pine,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: subText,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  tabs: const [
                    Tab(text: '🎁 Free Mindful Ads'),
                    Tab(text: '👑 Sovereign Pass'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10.0),

            // Dual Tab Contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  FreeAdsTabView(isDark: isDark, userId: widget.userId),
                  SovereignStoreTabView(isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
