import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../rewards/data/sanctuary_billing_service.dart';

class UnlockResonancesBanner extends ConsumerWidget {
  final int incomingCount;

  const UnlockResonancesBanner({super.key, required this.incomingCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = themeState.mode == SanctuaryThemeMode.dark;
    final gold = isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;
    final surface = isDark ? DarkSanctuaryTokens.surface : LightSanctuaryTokens.surface;
    final primary = isDark ? DarkSanctuaryTokens.primaryText : LightSanctuaryTokens.primaryText;
    final sub = isDark ? DarkSanctuaryTokens.secondaryText : LightSanctuaryTokens.secondaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.auto_awesome, color: gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$incomingCount Seekers Drawn to You',
                  style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 14, color: primary),
                ),
                Text(
                  'Unmask portraits & send direct letters.',
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ],
            ),
          ),
          // ACT-11 FIX: Real Google Play Billing Subscription Trigger
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              elevation: 0,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _handleStoreUnlock(context, ref),
            child: const Text(
              'Unlock ➔',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStoreUnlock(BuildContext context, WidgetRef ref) async {
    try {
      final billingService = ref.read(sanctuaryBillingServiceProvider);
      final products = await billingService.fetchAvailableProducts();
      final monthlyPass = products.firstWhere(
        (p) => p.id == 'urheart_pass_monthly',
        orElse: () => products.first,
      );

      await billingService.initiateStorePurchase(monthlyPass);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to connect to Google Play: ${e.toString()}')),
        );
      }
    }
  }
}
