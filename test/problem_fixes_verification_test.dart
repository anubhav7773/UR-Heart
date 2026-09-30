import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/features/feed/domain/candidate_profile.dart';
import 'package:ur_heart/core/services/sanctuary_notification_service.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';
import 'package:ur_heart/features/auth/presentation/controllers/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Problem 1: AuthState and Route Verification', () {
    test('AuthState exposes userId alias for authenticatedUserId', () {
      const state = AuthState(authenticatedUserId: 'user_xyz123');
      expect(state.userId, equals('user_xyz123'));

      const unauthState = AuthState();
      expect(unauthState.userId, equals(''));
    });
  });

  group('Problem 2: CandidateProfile KYC Verification and Photo Defaults', () {
    test('CandidateProfile defaults isVerified to false unless explicitly verified', () {
      final unverifiedJson = {
        'id': 'cand_1',
        'name': 'Priya Sharma',
        'age': 24,
        'bio': 'Lover of morning tea and literature',
        'location': 'New Delhi',
        'avatar_url': 'https://example.com/p1.webp',
        'kyc_status': false,
      };

      final profile = CandidateProfile.fromJson(unverifiedJson);
      expect(profile.isVerified, isFalse);
    });

    test('CandidateProfile correctly sets isVerified to true only when kyc_status is true', () {
      final verifiedJson = {
        'id': 'cand_2',
        'name': 'Rohan Sen',
        'age': 27,
        'bio': 'Architect exploring quiet sanctuaries',
        'location': 'Mumbai',
        'avatar_url': 'https://example.com/p2.webp',
        'kyc_status': true,
      };

      final profile = CandidateProfile.fromJson(verifiedJson);
      expect(profile.isVerified, isTrue);
    });
  });

  group('Problem 3: Notification Service Initialization', () {
    test('SanctuaryNotificationService singleton provides channel configurations', () {
      final service = SanctuaryNotificationService.instance;
      expect(service, isNotNull);
      expect(SanctuaryNotificationService.dialogueChannelId, equals('ur_heart_sacred_dialogue'));
      expect(SanctuaryNotificationService.presenceChannelId, equals('ur_heart_presence_channel'));
    });
  });

  group('Problem 4: Feed State Quota and Direct Letter Count', () {
    test('FeedState initializes with proper defaults', () {
      const state = FeedState(directLettersCount: 2);
      expect(state.directLettersCount, equals(2));
      expect(state.swipesRemaining, equals(10));
    });

    test('FeedState can update direct letters count cleanly', () {
      const state = FeedState(directLettersCount: 0);
      final updated = state.copyWith(directLettersCount: 5);
      expect(updated.directLettersCount, equals(5));
    });
  });
}
