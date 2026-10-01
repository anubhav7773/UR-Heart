import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/core/storage/secure_session_storage.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart' as persona_repo;
import 'package:ur_heart/features/profile/domain/user_profile_model.dart';
import 'package:ur_heart/features/profile_setup/data/profile_repository.dart' as setup_repo;
import 'package:ur_heart/features/profile_setup/presentation/controllers/profile_setup_controller.dart';

class MockSetupRepo extends setup_repo.ProfileRepository {
  Map<String, dynamic>? lastSavedPayload;

  MockSetupRepo() : super(ApiClient());

  @override
  Future<bool> saveUserProfile(Map<String, dynamic> data) async {
    lastSavedPayload = data;
    return true;
  }
}

class MockPersonaRepo extends persona_repo.ProfileRepository {
  @override
  Future<UserProfile> fetchMyProfile() async {
    return const UserProfile(
      id: 'usr_test_123',
      fullName: 'Anubhav Thakur',
      email: 'anubhav@example.com',
      age: 24,
      dobVerificationPill: '26 Mar 2002 · LOCKED & VERIFIED',
      gender: 'Man',
      interestedIn: 'Women',
      maskedWhatsApp: '+91 **** ****',
      memberSinceText: 'Member of Sanctuary',
      hasVerifiedCrest: true,
      location: 'Ayodhya, Uttar Pradesh',
      bio: 'Mindful explorer',
      profession: 'Engineer',
      education: 'B.Tech',
      minAgePref: 18.0,
      maxAgePref: 35.0,
      avatarUrl: 'https://r2.storage.com/users/anubhav/moments/slot_1.webp',
      momentPhotos: ['', '', '', ''],
      revealTokensCount: 1, // Token after successful backend claim
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Problem 1 Fix: Profile Photo & Moment Slots Isolation', () {
    test('UserProfile.fromJson does NOT duplicate avatar into momentPhotos[0] when only avatar uploaded', () {
      final json = {
        'id': 'usr_1',
        'full_name': 'Anubhav Thakur',
        'avatar_url': 'https://r2.storage.com/users/anubhav/moments/slot_1.webp',
        // In buggy state, photos only contained the avatar
        'photos': ['https://r2.storage.com/users/anubhav/moments/slot_1.webp'],
      };

      final profile = UserProfile.fromJson(json);

      // Avatar must be set
      expect(profile.avatarUrl, 'https://r2.storage.com/users/anubhav/moments/slot_1.webp');

      // Sacred Moments must have 4 slots and NOT contain the duplicate avatar in slot #1
      expect(profile.momentPhotos.length, 4);
      expect(profile.momentPhotos[0], '', reason: 'Moment #1 must not be populated with the duplicate avatar photo');
      expect(profile.momentPhotos[1], '');
      expect(profile.momentPhotos[2], '');
      expect(profile.momentPhotos[3], '');
    });

    test('UserProfile.fromJson accurately handles legacy 5-slot payload', () {
      final json = {
        'id': 'usr_2',
        'full_name': 'Test User',
        'avatar_url': 'https://r2.storage.com/users/slot_1.webp',
        'photos': [
          'https://r2.storage.com/users/slot_1.webp', // slot 1 (avatar)
          'https://r2.storage.com/users/slot_2.webp', // slot 2 (moment 1)
          'https://r2.storage.com/users/slot_3.webp', // slot 3 (moment 2)
          '',
          '',
        ],
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.avatarUrl, 'https://r2.storage.com/users/slot_1.webp');
      expect(profile.momentPhotos.length, 4);
      expect(profile.momentPhotos[0], 'https://r2.storage.com/users/slot_2.webp');
      expect(profile.momentPhotos[1], 'https://r2.storage.com/users/slot_3.webp');
      expect(profile.momentPhotos[2], '');
      expect(profile.momentPhotos[3], '');
    });

    test('ProfileSetupController.completeSetup isolates avatar_url (slot 1) and photos (slots 2-5)', () async {
      final mockRepo = MockSetupRepo();
      final controller = ProfileSetupController(mockRepo);

      controller.setFullName('Anubhav Thakur');
      controller.setDob('26 Mar 2002', 24);

      // Simulate user uploading Slot 1 (Avatar) and Slot 2 (Moment 1)
      final dummyFile = File('${Directory.systemTemp.path}/test_avatar.jpg');
      await dummyFile.writeAsBytes([0, 1, 2, 3]);

      controller.state = controller.state.copyWith(
        isGpsVerified: true,
        photoSlots: {
          1: 'https://r2.storage.com/users/anubhav/slot_1.webp',
          2: 'https://r2.storage.com/users/anubhav/slot_2.webp',
        },
      );

      final success = await controller.completeSetup();
      expect(success, isTrue);

      final payload = mockRepo.lastSavedPayload;
      expect(payload, isNotNull);
      expect(payload!['avatar_url'], 'https://r2.storage.com/users/anubhav/slot_1.webp');

      final photosList = payload['photos'] as List;
      expect(photosList.length, 4);
      // Slot 1 must NOT be in photos[0]! Slot 2 must be in photos[0] (Moment 1)
      expect(photosList[0], 'https://r2.storage.com/users/anubhav/slot_2.webp');
      expect(photosList[1], '');
      expect(photosList[2], '');
      expect(photosList[3], '');
    });
  });

  group('Problem 2 Fix: Reward Token Progression & Persistence', () {
    test('applyReward increments whatsappProgress 0 -> 1 -> 2 -> grants Reveal Token', () {
      final controller = GrowthHubController(const GrowthHubState(
        revealTokensCount: 0,
        whatsappProgress: 0,
      ));

      // Watch Ad 1
      controller.applyReward('whatsapp_reveal');
      expect(controller.state.whatsappProgress, 1);
      expect(controller.state.revealTokensCount, 0);

      // Watch Ad 2
      controller.applyReward('whatsapp_reveal');
      expect(controller.state.whatsappProgress, 2);
      expect(controller.state.revealTokensCount, 0);

      // Watch Ad 3 (ritual complete 3/3 -> credits 1 token and resets progress)
      controller.applyReward('whatsapp_reveal');
      expect(controller.state.whatsappProgress, 0);
      expect(controller.state.revealTokensCount, 1);
      expect(controller.state.isWhatsappUnlocked, isTrue);
    });

    test('syncUserData keeps credited token when backend returns credited profile', () async {
      final mockPersonaRepo = MockPersonaRepo();
      final controller = GrowthHubController(mockPersonaRepo, null);

      controller.applyReward('whatsapp_reveal');
      controller.applyReward('whatsapp_reveal');
      controller.applyReward('whatsapp_reveal');
      expect(controller.state.revealTokensCount, 1);

      // When syncUserData runs after fixed backend endpoint:
      await controller.syncUserData();

      // Token count must remain 1 and NOT revert to 0!
      expect(controller.state.revealTokensCount, 1);
    });
  });

  group('SecureSessionStorage Tests', () {
    test('getUserId retrieves saved user id cleanly', () async {
      await SecureSessionStorage.instance.saveUserSession(
        userId: 'usr_abc_789',
        email: 'test@example.com',
      );

      final uid = await SecureSessionStorage.instance.getUserId();
      expect(uid, 'usr_abc_789');
    });
  });
}
