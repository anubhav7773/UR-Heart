import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/core/services/sanctuary_notification_service.dart';
import 'package:ur_heart/features/auth/data/auth_repository.dart';

import 'package:ur_heart/features/auth/presentation/controllers/auth_controller.dart';
import 'package:ur_heart/features/profile_setup/data/profile_repository.dart';
import 'package:ur_heart/features/profile_setup/presentation/controllers/profile_setup_controller.dart';
import 'package:ur_heart/features/settings/data/settings_repository.dart';
import 'package:ur_heart/features/settings/presentation/controllers/settings_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/features/auth/data/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Account Switch & Logout State Isolation Fixes', () {
    test('SettingsController.logout completely wipes all profile, DOB, GPS, KYC, consent, and photo keys', () async {
      SharedPreferences.setMockInitialValues({
        'ur_heart_auth_token': 'jwt_user_1',
        'auth_token': 'legacy_user_1',
        'ur_heart_user_email': 'user1@example.com',
        'ur_heart_user_name': 'User One',
        'ur_heart_user_id': 'u1_id',
        'profile_full_name': 'User One',
        'profile_dob': '15 May 1995',
        'ur_heart_selected_dob': '15 May 1995',
        'profile_age': 29,
        'ur_heart_user_age': 29,
        'ur_heart_dob_day': 15,
        'ur_heart_dob_month': 5,
        'ur_heart_dob_year': 1995,
        'profile_gender': 'Man',
        'profile_location': 'Saket, Ayodhya',
        'profile_bio': 'Authentic mindfulness.',
        'profile_profession': 'Architect',
        'profile_education': 'B.Arch',
        'profile_contact_bridge_platform': 'whatsapp',
        'profile_contact_bridge_handle': '+919999999999',
        'profile_gps_verified': true,
        'profile_gps_latitude': 26.79,
        'profile_gps_longitude': 82.20,
        'profile_is_kyc_verified': true,
        'profile_interested_in': 'Women',
        'profile_min_age': 22.0,
        'profile_max_age': 32.0,
        'profile_photo_slot_1': '/data/user/photo1.webp',
        'profile_photo_slot_2': '/data/user/photo2.webp',
        'ur_heart_direct_letters': 3,
        'ur_heart_consent_given': true,
        'urheart_theme_permanently_locked': true,
        'ur_heart_theme_locked': true,
        'ur_heart_profile_setup_completed': true,
        'ur_heart_has_entered_sanctuary': true,
      });

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(SettingsRepository()),
          apiClientProvider.overrideWithValue(ApiClient()),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(ApiClient(), GoogleAuthService()),
          ),
          profileRepositoryProvider.overrideWithValue(ProfileRepository(ApiClient())),
        ],
      );

      final authCtrl = container.read(authControllerProvider.notifier);
      authCtrl.setDateOfBirth(day: 15, month: 5, year: 1995);
      expect(container.read(authControllerProvider).selectedDay, equals(15));
      expect(container.read(authControllerProvider).selectedMonth, equals(5));
      expect(container.read(authControllerProvider).selectedYear, equals(1995));

      final settingsCtrl = container.read(settingsControllerProvider.notifier);
      await settingsCtrl.logout();

      final prefs = await SharedPreferences.getInstance();

      // Verify all session & identity tokens are wiped
      expect(prefs.getString('ur_heart_auth_token'), isNull);
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('ur_heart_user_email'), isNull);
      expect(prefs.getString('ur_heart_user_name'), isNull);

      // Verify all DOB keys are wiped
      expect(prefs.getString('profile_dob'), isNull);
      expect(prefs.getString('ur_heart_selected_dob'), isNull);
      expect(prefs.getInt('profile_age'), isNull);
      expect(prefs.getInt('ur_heart_user_age'), isNull);
      expect(prefs.getInt('ur_heart_dob_day'), isNull);
      expect(prefs.getInt('ur_heart_dob_month'), isNull);
      expect(prefs.getInt('ur_heart_dob_year'), isNull);

      // Verify all photo slots are wiped
      for (int i = 1; i <= 5; i++) {
        expect(prefs.getString('profile_photo_slot_$i'), isNull);
      }

      // Verify GPS, KYC, Consent, and settings flags are wiped
      expect(prefs.getBool('profile_gps_verified'), isNull);
      expect(prefs.getBool('profile_is_kyc_verified'), isNull);
      expect(prefs.getBool('ur_heart_consent_given'), isNull);
      expect(prefs.getBool('urheart_theme_permanently_locked'), isNull);
      expect(prefs.getBool('ur_heart_theme_locked'), isNull);
      expect(prefs.getBool('ur_heart_profile_setup_completed'), isNull);

      // Verify in-memory AuthState was completely reset to null DOB
      final postLogoutAuthState = container.read(authControllerProvider);
      expect(postLogoutAuthState.selectedDay, isNull);
      expect(postLogoutAuthState.selectedMonth, isNull);
      expect(postLogoutAuthState.selectedYear, isNull);

      // Verify in-memory ProfileSetupState was completely reset
      final postLogoutProfileState = container.read(profileSetupControllerProvider);
      expect(postLogoutProfileState.photoSlots, isEmpty);
    });

    test('AuthController.reset() restores clean neutral DOB state', () {
      final authCtrl = AuthController(AuthRepository(ApiClient(), GoogleAuthService()));
      authCtrl.setDateOfBirth(day: 10, month: 8, year: 1990);
      expect(authCtrl.state.selectedDay, equals(10));
      expect(authCtrl.state.selectedMonth, equals(8));
      expect(authCtrl.state.selectedYear, equals(1990));

      authCtrl.reset();
      expect(authCtrl.state.selectedDay, isNull);
      expect(authCtrl.state.selectedMonth, isNull);
      expect(authCtrl.state.selectedYear, isNull);
      expect(authCtrl.state.hasSelectedFullDob, isFalse);
    });

    test('ProfileSetupController.reset() and loadSavedProfile() does not leak stale photo slots', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ProfileSetupController(ProfileRepository(ApiClient()));

      controller.reset();
      expect(controller.state.photoSlots, isEmpty);
      expect(controller.state.fullName, isEmpty);

      await controller.loadSavedProfile();
      expect(controller.state.photoSlots, isEmpty);
    });

    test('SanctuaryNotificationService.instance.cancelAll() executes safely', () async {
      final notifService = SanctuaryNotificationService.instance;
      await expectLater(notifService.cancelAll(), completes);
    });
  });
}
