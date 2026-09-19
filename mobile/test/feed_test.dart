import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';
import 'package:ur_heart/features/feed/presentation/widgets/feed_card.dart';

void main() {
  group('CandidateProfileModel JSON Serialization & Geo Privacy', () {
    test('Correctly deserializes candidate JSON with coarse distance and badge', () {
      final json = {
        'id': 'c8f498c4-e8b2-4d6c-b3a1-7c9e0f1a2b3c',
        'full_name': 'Ananya Sharma',
        'age': 23,
        'gender': 'female',
        'city': 'Lucknow',
        'bio': 'Coffee enthusiast, book lover, exploring Lucknow',
        'distance_km': 7,
        'distance_badge': 'Nearby 7 km',
        'kyc_status': true,
        'streak_count': 12,
        'interests': ['Chai', 'Poetry', 'Travel'],
        'photos': [
          {
            'slot_index': 1,
            'photo_storage_path': 'https://example.com/photos/ananya1.jpg',
            'blur_hash': 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
          }
        ],
      };

      final candidate = CandidateProfileModel.fromJson(json);

      expect(candidate.id, equals('c8f498c4-e8b2-4d6c-b3a1-7c9e0f1a2b3c'));
      expect(candidate.fullName, equals('Ananya Sharma'));
      expect(candidate.age, equals(23));
      expect(candidate.gender, equals('female'));
      expect(candidate.city, equals('Lucknow'));
      expect(candidate.bio, contains('Coffee enthusiast'));
      expect(candidate.distanceKm, equals(7));
      expect(candidate.distanceBadge, equals('Nearby 7 km'));
      expect(candidate.kycStatus, isTrue);
      expect(candidate.streakCount, equals(12));
      expect(candidate.interests, contains('Chai'));
      expect(candidate.photos.length, equals(1));
      expect(candidate.primaryPhotoUrl, equals('https://example.com/photos/ananya1.jpg'));
    });

    test('Falls back safely on missing distance fields without leaking coordinates', () {
      final json = {
        'id': 'd1e2f3a4-b5c6-7d8e-9f0a-1b2c3d4e5f6a',
        'full_name': 'Rahul Verma',
        'age': 25,
        'gender': 'male',
        'city': 'Kanpur',
      };

      final candidate = CandidateProfileModel.fromJson(json);

      expect(candidate.distanceKm, equals(5));
      expect(candidate.distanceBadge, equals('Nearby 5 km'));
      expect(candidate.photos, isEmpty);
      expect(candidate.primaryPhotoUrl, isEmpty);
    });

    test('SwipeResult deserializes mutual match, whatsapp unlocked, and remaining tokens', () {
      final json = {
        'target_user_id': 'c8f498c4-e8b2-4d6c-b3a1-7c9e0f1a2b3c',
        'swipe_type': 'direct_dm',
        'is_match': true,
        'match_id': 'm1a2t3c4-h5i6-7d8e-9f0a-1b2c3d4e5f6a',
        'whatsapp_unlocked': false,
        'remaining_dm_tokens': 4,
      };

      final swipeResult = SwipeResult.fromJson(json);

      expect(swipeResult.targetUserId, equals('c8f498c4-e8b2-4d6c-b3a1-7c9e0f1a2b3c'));
      expect(swipeResult.swipeType, equals('direct_dm'));
      expect(swipeResult.isMatch, isTrue);
      expect(swipeResult.matchId, equals('m1a2t3c4-h5i6-7d8e-9f0a-1b2c3d4e5f6a'));
      expect(swipeResult.whatsappUnlocked, isFalse);
      expect(swipeResult.remainingDmTokens, equals(4));
    });

    test('FeedCandidateModel extracts photo_url and photo_storage_path gracefully', () {
      final json = {
        'user_id': 'e1f2a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b',
        'full_name': 'Kavya Patel',
        'city': 'Varanasi',
        'detected_locality': 'Assi Ghat',
        'distance_km': 3,
        'gender': 'female',
        'bio': 'Ghat sunsets & classical music',
        'streak_count': 7,
        'photos': [
          {
            'slot_index': 1,
            'photo_url': 'https://pzrsyxvjbmzqlzlehuxg.supabase.co/storage/v1/object/public/user-photos/u1/slot_1.webp',
            'blur_hash': 'LEHLh[WB2yk8pyoJadR*.7kCMdnj',
          },
          {
            'slot_index': 2,
            'photo_storage_path': 'https://images.unsplash.com/photo-seed2',
          },
        ],
      };

      final candidate = FeedCandidateModel.fromJson(json);

      expect(candidate.userId, equals('e1f2a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b'));
      expect(candidate.id, equals('e1f2a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b'));
      expect(candidate.fullName, equals('Kavya Patel'));
      expect(candidate.city, equals('Varanasi'));
      expect(candidate.detectedLocality, equals('Assi Ghat'));
      expect(candidate.distanceKm, equals(3));
      expect(candidate.streakCount, equals(7));
      expect(candidate.photos.length, equals(2));
      expect(candidate.photos[0].photoUrl, startsWith('https://'));
      expect(candidate.photos[1].photoUrl, equals('https://images.unsplash.com/photo-seed2'));
      expect(candidate.photos[1].blurHash, equals('LEHLh[WB2yk8pyoJadR*.7kCMdnj'));
    });

    testWidgets('FeedCard renders candidate info, story bars, and responds to actions', (tester) async {
      bool liked = false;
      bool passed = false;
      bool directDmed = false;

      final candidate = FeedCandidateModel(
        userId: 'u123',
        fullName: 'Meera Kapoor',
        city: 'Lucknow',
        detectedLocality: 'Gomti Nagar',
        distanceKm: 4,
        gender: 'female',
        bio: 'Art and architecture lover',
        streakCount: 5,
        photos: [
          CandidatePhotoModel(
            slotIndex: 1,
            photoUrl: 'https://example.com/photo1.webp',
            blurHash: 'LEHLh[WB2yk8pyoJadR*.7kCMdnj',
          ),
          CandidatePhotoModel(
            slotIndex: 2,
            photoUrl: 'https://example.com/photo2.webp',
            blurHash: 'LEHLh[WB2yk8pyoJadR*.7kCMdnj',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 400,
              child: FeedCard(
                candidate: candidate,
                onLike: () => liked = true,
                onPass: () => passed = true,
                onDirectDm: () => directDmed = true,
              ),
            ),
          ),
        ),
      );

      // Verify name, locality and streak rendered
      expect(find.text('Meera Kapoor'), findsOneWidget);
      expect(find.text('Nearby 4 km'), findsOneWidget);
      expect(find.text('🔥 5 Day Streak'), findsOneWidget);
      expect(find.text('Art and architecture lover'), findsOneWidget);

      // Verify Action buttons rendered and interactive
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Tap like button
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();
      expect(liked, isTrue);

      // Tap pass button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(passed, isTrue);

      // Tap direct dm button
      await tester.tap(find.byIcon(Icons.flash_on_rounded));
      await tester.pump();
      expect(directDmed, isTrue);
    });
  });
}
