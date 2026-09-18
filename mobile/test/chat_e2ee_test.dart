import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/security/chat_crypto_service.dart';
import 'package:ur_heart/features/chat/data/chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatCryptoService E2EE AES-256 Tests', () {
    const matchId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
    const otherMatchId = 'f1e2d3c4-b5a6-7890-1234-56789abcdef0';
    const plainText = 'Hey! How are you doing today? 🔒❤️';

    test('encryptMessage outputs valid e2ee:{iv}:{ciphertext} format', () {
      final encrypted = ChatCryptoService.encryptMessage(plainText, matchId);

      expect(encrypted.startsWith('e2ee:'), isTrue);
      final parts = encrypted.split(':');
      expect(parts.length, 3);
      expect(parts[0], 'e2ee');
      // IV is 16 bytes base64 encoded -> 24 chars
      expect(parts[1].isNotEmpty, isTrue);
      // Ciphertext is non-empty base64
      expect(parts[2].isNotEmpty, isTrue);
    });

    test('isEncrypted identifies encrypted vs plain text accurately', () {
      final encrypted = ChatCryptoService.encryptMessage(plainText, matchId);
      expect(ChatCryptoService.isEncrypted(encrypted), isTrue);
      expect(ChatCryptoService.isEncrypted(plainText), isFalse);
      expect(ChatCryptoService.isEncrypted('e2ee:invalid'), isFalse);
    });

    test('encryptMessage and decryptMessage successfully round-trip', () {
      final encrypted = ChatCryptoService.encryptMessage(plainText, matchId);
      final decrypted = ChatCryptoService.decryptMessage(encrypted, matchId);

      expect(decrypted, equals(plainText));
    });

    test('decryptMessage returns fallback on wrong match key', () {
      final encrypted = ChatCryptoService.encryptMessage(plainText, matchId);
      // Decrypting with wrong match ID (wrong key) fails gracefully
      final failedDecrypted = ChatCryptoService.decryptMessage(encrypted, otherMatchId);

      expect(failedDecrypted, contains('Unable to decrypt'));
    });

    test('decryptMessage returns original string if not encrypted (backwards compatibility)', () {
      const legacyMessage = 'Hello from legacy client!';
      final result = ChatCryptoService.decryptMessage(legacyMessage, matchId);

      expect(result, equals(legacyMessage));
    });

    test('Two different encryptions of same text have distinct IVs (non-deterministic cipher)', () {
      final enc1 = ChatCryptoService.encryptMessage(plainText, matchId);
      final enc2 = ChatCryptoService.encryptMessage(plainText, matchId);

      // IVs should be different
      expect(enc1, isNot(equals(enc2)));

      // But both decrypt back to original
      expect(ChatCryptoService.decryptMessage(enc1, matchId), equals(plainText));
      expect(ChatCryptoService.decryptMessage(enc2, matchId), equals(plainText));
    });
  });

  group('ChatMessageModel & WhatsApp Tick Status Tests', () {
    const matchId = '11111111-2222-3333-4444-555555555555';
    final now = DateTime.now();

    test('ChatMessageModel defaults to sent status', () {
      final msg = ChatMessageModel(
        id: 'msg-001',
        matchId: matchId,
        senderId: 'user-1',
        content: 'Hi!',
        status: 'sent',
        createdAt: now,
      );

      expect(msg.status, equals('sent'));
    });

    test('ChatMessageModel copyWith handles status transitions sent -> delivered -> read', () {
      final msgSent = ChatMessageModel(
        id: 'msg-001',
        matchId: matchId,
        senderId: 'user-1',
        content: 'Hi!',
        status: 'sent',
        createdAt: now,
      );

      // 1. Double grey tick (delivered)
      final msgDelivered = msgSent.copyWith(status: 'delivered');
      expect(msgDelivered.status, equals('delivered'));

      // 2. Double blue tick (read)
      final msgRead = msgDelivered.copyWith(status: 'read');
      expect(msgRead.status, equals('read'));
    });

    test('ChatMessageModel.fromJson automatically decrypts encrypted_text payload', () {
      const rawText = 'Secret WhatsApp Message';
      final encryptedPayload = ChatCryptoService.encryptMessage(rawText, matchId);

      final json = {
        'id': 'msg-100',
        'match_id': matchId,
        'sender_id': 'user-2',
        'encrypted_text': encryptedPayload,
        'status': 'read',
        'created_at': now.toIso8601String(),
      };

      final model = ChatMessageModel.fromJson(json, matchId: matchId);
      expect(model.id, equals('msg-100'));
      expect(model.content, equals(rawText)); // Auto decrypted!
      expect(model.status, equals('read'));
    });
  });
}
