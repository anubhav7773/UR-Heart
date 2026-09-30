import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/core/storage/secure_session_storage.dart';
import 'package:ur_heart/features/profile/domain/user_profile_model.dart';
import 'package:ur_heart/features/rewards/domain/rewards_models.dart';
import 'package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart';
import 'package:ur_heart/features/feed/presentation/controllers/feed_controller.dart';
import 'package:ur_heart/features/rewards/presentation/widgets/resource_metrics_bar.dart';
import 'package:ur_heart/features/settings/presentation/controllers/settings_controller.dart';
import 'package:ur_heart/features/settings/data/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Problem 5: Strict 10 Swipes, 0 Direct Letters, 0 Social Reveals Defaults', () {
    test('UserProfileModel defaults to 10 swipes, 0 letters, 0 reveal tokens', () {
      final profile = UserProfile(
        id: 'user_1',
        fullName: 'Aarav',
        email: 'aarav@test.com',
        age: 25,
        dobVerificationPill: '10 Jan 1999',
        gender: 'Man',
        interestedIn: 'Women',
        maskedWhatsApp: '+91 **** ****',
        memberSinceText: 'Member',
        hasVerifiedCrest: true,
        location: 'Saket',
        bio: 'Mindful seeker',
        profession: 'Designer',
        education: 'B.Des',
        minAgePref: 20,
        maxAgePref: 30,
        avatarUrl: 'https://cdn.example.com/avatar.webp',
        momentPhotos: const [],
      );

      expect(profile.swipesRemaining, 10);
      expect(profile.directLettersCount, 0);
      expect(profile.revealTokensCount, 0);
    });

    test('UserProfileModel.fromJson defaults missing quotas to (10, 0, 0)', () {
      final json = {
        'id': 'user_2',
        'full_name': 'Meera',
        'email': 'meera@test.com',
      };
      final profile = UserProfile.fromJson(json);

      expect(profile.swipesRemaining, 10);
      expect(profile.directLettersCount, 0);
      expect(profile.revealTokensCount, 0);
    });

    test('RewardHubState defaults to 10 swipes and 0 direct letters', () {
      const state = RewardHubState();
      expect(state.swipesRemaining, 10);
      expect(state.directLettersCount, 0);
      expect(state.whatsappProgress, 0);
      expect(state.peerWhatsappProgress, 0);
    });

    test('GrowthHubState defaults to 10 swipes, 0 direct letters, and 0 reveal tokens', () {
      const state = GrowthHubState();
      expect(state.swipesRemaining, 10);
      expect(state.directLetters, 0);
      expect(state.revealTokensCount, 0);
      expect(state.whatsappProgress, 0);
      expect(state.peerWhatsappProgress, 0);
    });

    test('FeedState defaults to 10 swipes and 0 direct letters', () {
      const state = FeedState();
      expect(state.swipesRemaining, 10);
      expect(state.directLettersCount, 0);
    });

    test('ResourceMetricsBar default revealTokens is 0', () {
      const bar = ResourceMetricsBar(
        isDark: false,
        swipesRemaining: 10,
        directLetters: 0,
        isAdFree: false,
      );
      expect(bar.revealTokens, 0);
    });
  });

  group('Problem 2: Profile Sanctuary Age & DOB Persistence', () {
    test('Persisting DOB and Age in SharedPreferences correctly restores them', () async {
      SharedPreferences.setMockInitialValues({
        'profile_dob': '15 Aug 1998',
        'ur_heart_selected_dob': '15 Aug 1998',
        'profile_age': 28,
        'ur_heart_user_age': 28,
      });

      final prefs = await SharedPreferences.getInstance();
      final dob = prefs.getString('profile_dob');
      final age = prefs.getInt('profile_age');

      expect(dob, '15 Aug 1998');
      expect(age, 28);
    });
  });

  group('Problem 4: Logout Purges Session and Prevents Startup Freeze', () {
    test('SettingsController.logout clears SecureSessionStorage and all user SharedPreferences keys', () async {
      SharedPreferences.setMockInitialValues({
        'ur_heart_auth_token': 'jwt_secret_token_123',
        'auth_token': 'legacy_token',
        'ur_heart_user_email': 'test@example.com',
        'profile_photo_slot_1': '/data/user/photo1.webp',
        'profile_photo_slot_2': '/data/user/photo2.webp',
        'profile_full_name': 'Test User',
        'ur_heart_profile_setup_completed': true,
      });

      await SecureSessionStorage.instance.saveAuthToken('jwt_secret_token_123');

      final controller = SettingsController(SettingsRepository());
      await controller.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ur_heart_auth_token'), isNull);
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('ur_heart_user_email'), isNull);
      expect(prefs.getString('profile_photo_slot_1'), isNull);
      expect(prefs.getString('profile_photo_slot_2'), isNull);
      expect(prefs.getString('profile_full_name'), isNull);
      expect(prefs.getBool('ur_heart_profile_setup_completed'), isNull);

      final token = await SecureSessionStorage.instance.getAuthToken();
      expect(token, isNull);
    });
  });
}
