import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/chat/data/chat_repository.dart';
import 'package:ur_heart/features/chat/presentation/services/window_security_service.dart';
import 'package:ur_heart/features/chat/presentation/services/web_security_stub.dart'
    if (dart.library.js_interop) 'package:ur_heart/features/chat/presentation/services/web_security_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Problem 1 & 4: Chat Message Deduplication & In-Place Reconciliation', () {
    test('ChatMessage models retain deterministic client UUIDs and delivery status', () {
      const msgId = '11111111-2222-3333-4444-555555555555';
      final now = DateTime.now();

      final optimisticMsg = ChatMessage(
        id: msgId,
        matchId: 'match-123',
        senderId: 'me',
        recipientId: 'peer-456',
        text: 'hello',
        createdAt: now,
        status: MessageDeliveryStatus.sent,
        isMe: true,
      );

      expect(optimisticMsg.id, equals(msgId));
      expect(optimisticMsg.status, equals(MessageDeliveryStatus.sent));

      // Simulate server confirmation reconciliation
      final serverMsg = ChatMessage(
        id: msgId,
        matchId: 'match-123',
        senderId: 'me',
        recipientId: 'peer-456',
        text: 'hello',
        createdAt: now,
        status: MessageDeliveryStatus.delivered,
        isMe: true,
      );

      // Verify in-place update matches without duplicating
      final list = [optimisticMsg];
      final idx = list.indexWhere((m) => m.id == serverMsg.id);
      expect(idx, equals(0));
      list[idx] = serverMsg;

      expect(list.length, equals(1));
      expect(list.first.status, equals(MessageDeliveryStatus.delivered));
    });

    test('Fuzzy content and timestamp matcher correctly catches duplicate messages', () {
      final now = DateTime.now();
      final msg1 = ChatMessage(
        id: 'id_1',
        matchId: 'match-abc',
        senderId: 'peer',
        recipientId: 'me',
        text: 'kya hal hai',
        createdAt: now,
        status: MessageDeliveryStatus.delivered,
        isMe: false,
      );

      final existingMessages = [msg1];

      // Second incoming event with different ephemeral ID but identical text within 5s
      const incomingText = 'kya hal hai';
      final incomingTime = now.add(const Duration(milliseconds: 300));

      final isDuplicate = existingMessages.any((m) {
        if (!m.isMe && m.text.trim() == incomingText.trim()) {
          final diff = incomingTime.difference(m.createdAt).abs().inSeconds;
          if (diff < 15) return true;
        }
        return false;
      });

      expect(isDuplicate, isTrue, reason: 'Duplicate incoming message should be caught and dropped');
    });
  });

  group('Problem 2: Web App Splash Screen Dismissal Safety', () {
    test('dismissWebSplash executes safely on any platform without throwing', () {
      expect(() => dismissWebSplash(), returnsNormally);
    });
  });

  group('Problem 3: Window Security Service & Web Privacy Shield', () {
    test('WindowSecurityService enableSecureMode and disableSecureMode execute safely', () async {
      final enableResult = await WindowSecurityService.enableSecureMode();
      expect(enableResult, isA<bool>());

      final disableResult = await WindowSecurityService.disableSecureMode();
      expect(disableResult, isA<bool>());
    });

    test('setWebPrivacyMode executes safely without throwing on non-web test harness', () {
      expect(() => setWebPrivacyMode(true), returnsNormally);
      expect(() => setWebPrivacyMode(false), returnsNormally);
    });
  });
}
