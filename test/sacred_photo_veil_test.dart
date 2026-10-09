import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/profile/domain/user_profile_model.dart';
import 'package:ur_heart/features/profile/presentation/widgets/sacred_photo_veil_card.dart';
import 'package:ur_heart/features/feed/domain/candidate_profile.dart';
import 'package:ur_heart/features/feed/presentation/widgets/photo_carousel_with_dots.dart';
import 'package:ur_heart/features/settings/domain/settings_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sacred Photo Veil Domain Models', () {
    test('CandidateProfile correctly serializes and deserializes photo veil fields', () {
      final profile = CandidateProfile(
        id: 'candidate-uuid-1234',
        fullName: 'Tara Sharma',
        age: 23,
        gender: 'Woman',
        lookingFor: 'Everyone',
        locationName: 'Saket, Ayodhya',
        distanceKm: 2.5,
        resonanceScore: 92,
        intentQuote: 'Mindful architecture and quiet coffee',
        interests: const ['Architecture', 'Presence'],
        photoUrls: const ['https://example.com/photo1.jpg'],
        blurHashes: const ['L6PZfSi_'],
        isPhotoVeiled: true,
        isPhotoUnlocked: false,
        photoRevealStatus: 'pending',
      );

      expect(profile.name, equals('Tara Sharma'));
      expect(profile.isPhotoVeiled, isTrue);
      expect(profile.isPhotoUnlocked, isFalse);
      expect(profile.photoRevealStatus, equals('pending'));

      final map = profile.toMap();
      expect(map['is_photo_veiled'], isTrue);
      expect(map['is_photo_unlocked'], isFalse);
      expect(map['photo_reveal_status'], equals('pending'));

      final parsed = CandidateProfile.fromJson(map);
      expect(parsed.name, equals('Tara Sharma'));
      expect(parsed.isPhotoVeiled, isTrue);
      expect(parsed.isPhotoUnlocked, isFalse);
      expect(parsed.photoRevealStatus, equals('pending'));
    });

    test('UserProfile correctly handles isPhotoVeiled copyWith and JSON conversion', () {
      final profile = UserProfile.fromJson({
        'id': 'user-uuid-5678',
        'full_name': 'Devan',
        'email': 'devan@sanctuary.internal',
        'age': 24,
        'is_photo_veiled': false,
      });

      expect(profile.isPhotoVeiled, isFalse);
      final updated = profile.copyWith(isPhotoVeiled: true);
      expect(updated.isPhotoVeiled, isTrue);

      final json = updated.toJson();
      expect(json['is_photo_veiled'], isTrue);

      final reloaded = UserProfile.fromJson(json);
      expect(reloaded.isPhotoVeiled, isTrue);
    });

    test('SanctuarySettings correctly updates isPhotoVeiled', () {
      const settings = SanctuarySettings();
      expect(settings.isPhotoVeiled, isFalse);

      final updated = settings.copyWith(isPhotoVeiled: true);
      expect(updated.isPhotoVeiled, isTrue);

      const pref = UserPreferences(isPhotoVeiled: true);
      expect(pref.toJson()['is_photo_veiled'], isTrue);
    });
  });

  group('Sacred Photo Veil Widgets', () {
    testWidgets('SacredPhotoVeilCard renders toggle switch and fires onChanged callback', (tester) async {
      bool toggleValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SacredPhotoVeilCard(
                  isVeiled: toggleValue,
                  isDark: false,
                  onChanged: (val) {
                    setState(() {
                      toggleValue = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Sacred Photo Veil'), findsOneWidget);
      expect(find.text('CLEAR ✨'), findsOneWidget);

      // Tap the Switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(toggleValue, isTrue);
      expect(find.text('VEILED 🔒'), findsOneWidget);
    });

    testWidgets('PhotoCarouselWithDots renders Sacred Photo Veil overlay when veiled and locked', (tester) async {
      bool revealRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoCarouselWithDots(
              photos: const ['https://example.com/test.jpg'],
              blurHashes: const [],
              isDark: true,
              isPhotoVeiled: true,
              isPhotoUnlocked: false,
              photoRevealStatus: 'none',
              onRequestReveal: () {
                revealRequested = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sacred Photo Veil'), findsOneWidget);
      expect(find.text('Request Photo Reveal 🕊️'), findsOneWidget);

      await tester.tap(find.text('Request Photo Reveal 🕊️'));
      await tester.pump();

      expect(revealRequested, isTrue);
    });
  });
}
