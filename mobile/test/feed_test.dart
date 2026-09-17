import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/feed/data/feed_repository.dart';

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
  });
}
