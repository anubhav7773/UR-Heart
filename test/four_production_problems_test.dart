import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/growth/data/slumber_sensor_service.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/legal_vault/data/vault_repository.dart';
import 'package:ur_heart/features/legal_vault/presentation/widgets/blocked_perimeter_list.dart';
import 'package:ur_heart/features/rewards/data/sanctuary_billing_service.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/sovereign_store_tab_view.dart';

class FakeVaultRepository extends VaultRepository {
  FakeVaultRepository() : super(null);

  @override
  Future<List<BlockedProfile>> fetchBlockedUsers() async => [];

  @override
  Future<bool> unblockProfile(String id) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Problem 2: Monetization Plans Realignment', () {
    testWidgets('Sovereign Store renders 365 Days Pass, Mutual Consent Key, and 24h Passport @ Rs 99', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SovereignStoreTabView(
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Lifetime pass strictly 365 days
      expect(find.text('1-Year Sovereign Pass'), findsOneWidget);
      expect(find.text('365 Days Access'), findsOneWidget);

      // 2. Instant Contact Key with Mutual Consent
      expect(find.text('Instant Contact Key'), findsOneWidget);
      expect(find.text('Fast-track reveal with mutual consent'), findsOneWidget);

      // 3. 24h Global Passport @ Rs 99
      expect(find.text('24h Global Passport'), findsOneWidget);
      expect(find.textContaining('99'), findsWidgets);
    });

    test('Billing service contains 24h Global Passport @ 1.99 USD', () async {
      final billing = SanctuaryBillingService.instance;
      final products = await billing.fetchAvailableProducts();
      final passport = products.firstWhere(
        (p) => p.id == 'urheart_pack_global_passport',
      );
      expect(passport.price, equals('\$1.99'));
    });
  });

  group('Problem 3: Night Sanctuary Slumber Hardware & Persistence', () {
    test('SlumberSensorService hardware monitoring starts without uncaught errors', () {
      final sensor = SlumberSensorService.instance;
      expect(() => sensor.startHardwareMonitoring(), returnsNormally);
      expect(sensor.isMonitoring, isTrue);
    });

    test('GrowthHubController toggles Slumber Mode and persists to SharedPreferences', () async {
      final controller = GrowthHubController(
        const GrowthHubState(isSlumberActive: false),
      );

      await controller.toggleSlumberMode(true);
      expect(controller.state.isSlumberActive, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ur_heart_night_slumber'), isTrue);

      await controller.toggleSlumberMode(false);
      expect(controller.state.isSlumberActive, isFalse);
      expect(prefs.getBool('ur_heart_night_slumber'), isFalse);
    });
  });

  group('Problem 4: Statutory Blocked Perimeter Live Reactivity', () {
    testWidgets('BlockedPerimeterList renders blocked accounts and unblocks successfully', (tester) async {
      final dummyBlocked = [
        const BlockedProfile(
          id: 'test-user-block-1',
          name: 'Blocked User One',
          age: 26,
          dateBlocked: '2026-10-01',
        ),
      ];

      bool unblockedCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultRepositoryProvider.overrideWithValue(FakeVaultRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BlockedPerimeterList(
                blockedList: dummyBlocked,
                isDark: true,
                onUnblock: (id) {
                  unblockedCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Blocked Perimeter (1)'), findsOneWidget);
      expect(find.text('Blocked User One, 26'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);

      await tester.tap(find.text('Unblock'));
      await tester.pump();

      expect(unblockedCalled, isTrue);
      expect(find.text('Unblocked Blocked User One'), findsOneWidget);
    });
  });
}
