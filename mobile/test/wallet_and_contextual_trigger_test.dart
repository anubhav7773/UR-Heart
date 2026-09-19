import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/widgets/insufficient_credits_sheet.dart';
import 'package:ur_heart/features/wallet/data/wallet_repository.dart';

void main() {
  group('WalletBalanceModel & Repository Tests', () {
    test('Correctly deserializes WalletBalanceModel from JSON', () {
      final json = {
        'dm_credits': 3,
        'wa_reveal_tokens': 1,
        'missed_bio_passes': 2,
        'streak_shields': 0,
        'total_ads_watched': 5,
        'night_farm_ads_today': 4,
        'can_farm_tonight': true,
      };

      final model = WalletBalanceModel.fromJson(json);

      expect(model.dmCredits, equals(3));
      expect(model.waRevealTokens, equals(1));
      expect(model.missedBioPasses, equals(2));
      expect(model.streakShields, equals(0));
      expect(model.totalAdsWatched, equals(5));
      expect(model.nightFarmAdsToday, equals(4));
      expect(model.canFarmTonight, isTrue);
    });

    test('Falls back safely on missing fields in WalletBalanceModel', () {
      final json = <String, dynamic>{};

      final model = WalletBalanceModel.fromJson(json);

      expect(model.dmCredits, equals(0));
      expect(model.waRevealTokens, equals(0));
      expect(model.missedBioPasses, equals(0));
      expect(model.streakShields, equals(0));
      expect(model.totalAdsWatched, equals(0));
      expect(model.nightFarmAdsToday, equals(0));
      expect(model.canFarmTonight, isTrue);
    });
  });

  group('InsufficientCreditsSheet Widget Tests', () {
    testWidgets('Renders directDm actionType correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InsufficientCreditsSheet(
              actionType: CreditActionType.directDm,
              targetUserId: 'target-123',
              onCreditAcquired: () {},
            ),
          ),
        ),
      );

      expect(find.text('Direct DMs Finished / डीएम समाप्त!'), findsOneWidget);
      expect(find.text('Watch 10s Ad -> +1 Direct DM'), findsOneWidget);
      expect(find.text('Watch 20s Ad -> +2 Direct DMs'), findsOneWidget);
    });

    testWidgets('Renders waReveal actionType correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InsufficientCreditsSheet(
              actionType: CreditActionType.waReveal,
              targetUserId: 'target-456',
              onCreditAcquired: () {},
            ),
          ),
        ),
      );

      expect(find.text('WhatsApp Token Needed / टोकन चाहिए'), findsOneWidget);
      expect(find.text('Watch 30s Ad -> +1 Reveal Token'), findsOneWidget);
    });

    testWidgets('Renders missedBio actionType correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InsufficientCreditsSheet(
              actionType: CreditActionType.missedBio,
              targetUserId: 'target-789',
              onCreditAcquired: () {},
            ),
          ),
        ),
      );

      expect(find.text('Missed Bio Pass Required'), findsOneWidget);
      expect(find.text('Watch 10s Ad -> Unlock Bio'), findsOneWidget);
    });
  });
}
