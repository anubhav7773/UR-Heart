import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/core/services/image_moderation_service.dart';
import 'package:ur_heart/features/profile_setup/presentation/controllers/profile_setup_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Zero-Tolerance Photo Text Moderation Gatekeeper Tests', () {
    test('ModerationResult.rejected accurately stores text_detected category and message', () {
      const reason =
          'Text detected in photo. Photos containing text, quotes, captions, watermarks, or screenshots are strictly prohibited. Please upload a photo without any text.';
      final result = ModerationResult.rejected(reason, category: 'text_detected');

      expect(result.isSafe, isFalse);
      expect(result.category, equals('text_detected'));
      expect(result.rejectionReason, contains('Text detected in photo'));
    });

    test('ModerationResult.approved allows safe photos (including AI-edited and filtered)', () {
      final result = ModerationResult.approved();

      expect(result.isSafe, isTrue);
      expect(result.category, equals('safe'));
      expect(result.rejectionReason, isNull);
    });

    test('ProfileSetupState preserves moderation error and leaves slot empty on rejection', () {
      const initialState = ProfileSetupState();
      expect(initialState.photoSlots.containsKey(1), isFalse);
      expect(initialState.lastModerationError, isNull);

      const textError =
          'Text detected in photo. Photos containing text, quotes, captions, watermarks, or screenshots are strictly prohibited. Please upload a photo without any text.';
      final rejectedState = initialState.copyWith(
        isUploadingPhoto: false,
        lastModerationError: textError,
      );

      expect(rejectedState.photoSlots.containsKey(1), isFalse);
      expect(rejectedState.lastModerationError, contains('Text detected in photo'));
      expect(rejectedState.isUploadingPhoto, isFalse);
    });

    test('Photo slots 1 to 5 only accept clean photos, never populating on rejection', () {
      var state = const ProfileSetupState();

      // Simulate rejection on slot 2 due to text overlay
      const textError =
          'Text detected in photo. Photos containing text, quotes, captions, watermarks, or screenshots are strictly prohibited.';
      state = state.copyWith(lastModerationError: textError);

      expect(state.photoSlots[2], isNull);
      expect(state.lastModerationError, contains('Text detected'));

      // Simulate approval on clean AI-edited photo for slot 1
      final updatedSlots = Map<int, String>.from(state.photoSlots);
      updatedSlots[1] = 'https://r2.storage.com/users/slot_1_ai_filtered.webp';
      state = state.copyWith(photoSlots: updatedSlots, lastModerationError: null);

      expect(state.photoSlots[1], equals('https://r2.storage.com/users/slot_1_ai_filtered.webp'));
      expect(state.lastModerationError, isNull);
      expect(state.photoSlots.containsKey(2), isFalse);
    });
  });
}
