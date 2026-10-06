import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/blind_date/domain/blind_date_models.dart';
import 'package:ur_heart/features/blind_date/presentation/controllers/blind_date_controller.dart';
import 'package:ur_heart/features/chat/presentation/services/window_security_service.dart';

void main() {
  group('Blind Date Domain Models & DPDP Privacy Shield Tests', () {
    test('BlindDatePartner parses veiled state with ZERO raw photos leaked', () {
      final json = {
        'id': 'user-123',
        'name': 'Aarav',
        'age': 25,
        'gender': 'man',
        'location': 'Indore',
        'bio': 'Veiled in Sanctuary mystery...',
        'photos': <String>[],
        'avatar_url': null,
        'voice_spark_url': 'https://r2.urheart.app/voice/sample.m4a',
        'voice_spark_prompt': 'A song that feels like me',
        'voice_spark_duration': 6.8,
        'is_voice_verified': true,
        'is_revealed': false,
        'blur_radius': 35.0,
      };

      final partner = BlindDatePartner.fromJson(json);

      expect(partner.id, 'user-123');
      expect(partner.name, 'Aarav');
      expect(partner.age, 25);
      expect(partner.gender, 'man');
      expect(partner.photos, isEmpty);
      expect(partner.avatarUrl, isNull);
      expect(partner.isRevealed, isFalse);
      expect(partner.blurRadius, 35.0);
      expect(partner.voiceSparkUrl, 'https://r2.urheart.app/voice/sample.m4a');
      expect(partner.isVoiceVerified, isTrue);
    });

    test('BlindDatePartner supports 3rd gender ("other" / non-binary)', () {
      final json = {
        'id': 'user-456',
        'name': 'Robin',
        'age': 23,
        'gender': 'other',
        'location': 'Saket, Ayodhya',
        'bio': 'Veiled in Sanctuary mystery...',
        'photos': <String>[],
        'avatar_url': null,
        'is_revealed': false,
      };

      final partner = BlindDatePartner.fromJson(json);

      expect(partner.id, 'user-456');
      expect(partner.gender, 'other');
      expect(partner.isRevealed, isFalse);
    });

    test('BlindDatePartner parses unmasked state when mutually revealed', () {
      final json = {
        'id': 'user-789',
        'name': 'Pooja Sharma',
        'age': 24,
        'gender': 'woman',
        'location': 'Saket',
        'bio': 'Passionate reader & classical singer',
        'photos': ['https://r2.urheart.app/pooja_real.jpg'],
        'avatar_url': 'https://r2.urheart.app/pooja_real.jpg',
        'is_revealed': true,
        'blur_radius': 0.0,
      };

      final partner = BlindDatePartner.fromJson(json);

      expect(partner.name, 'Pooja Sharma');
      expect(partner.photos.length, 1);
      expect(partner.avatarUrl, 'https://r2.urheart.app/pooja_real.jpg');
      expect(partner.isRevealed, isTrue);
      expect(partner.blurRadius, 0.0);
    });

    test('BlindDateSessionModel parses active session with Eva prompt', () {
      final json = {
        'id': 'session-001',
        'status': 'active',
        'remaining_seconds': 285,
        'icebreaker_prompt': 'What song currently feels like a page torn from your journal?',
        'my_decision': 'pending',
        'partner_decision': 'hidden',
        'partner': {
          'id': 'user-123',
          'name': 'Soul Seeker',
          'age': 24,
          'gender': 'woman',
          'location': 'Sanctuary',
          'photos': <String>[],
          'is_revealed': false,
        },
      };

      final session = BlindDateSessionModel.fromJson(json);

      expect(session.id, 'session-001');
      expect(session.status, 'active');
      expect(session.remainingSeconds, 285);
      expect(session.icebreakerPrompt, contains('page torn from your journal'));
      expect(session.myDecision, 'pending');
      expect(session.partner?.name, 'Soul Seeker');
      expect(session.partner?.isRevealed, isFalse);
    });
  });

  group('Window Security Service Route Classification Tests', () {
    test('/blind-date and /blind-date-session are classified as sensitive routes', () {
      expect(WindowSecurityService.sensitiveRoutes.contains('/blind-date'), isTrue);
      expect(WindowSecurityService.sensitiveRoutes.contains('/blind-date-session'), isTrue);
    });
  });

  group('BlindDateState Unit Tests', () {
    test('Default BlindDateState starts idle with 300 seconds', () {
      const state = BlindDateState();
      expect(state.queueStatus, BlindDateQueueStatus.idle);
      expect(state.remainingSeconds, 300);
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('State copyWith updates status and seconds accurately', () {
      const state = BlindDateState();
      final updated = state.copyWith(
        queueStatus: BlindDateQueueStatus.waiting,
        remainingSeconds: 240,
      );
      expect(updated.queueStatus, BlindDateQueueStatus.waiting);
      expect(updated.remainingSeconds, 240);
    });
  });
}
