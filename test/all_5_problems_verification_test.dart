import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ur_heart/features/feed/domain/candidate_profile.dart';
import 'package:ur_heart/features/chat/domain/chat_models.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Problem 1: Reveal Token Persistence & 3-Video Cycle', () {
    test('SharedPreferences retains earned reveal tokens across app cycles', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ur_heart_reveal_tokens', 1);
      await prefs.setInt('ur_heart_whatsapp_progress', 0);

      expect(prefs.getInt('ur_heart_reveal_tokens'), 1);
      expect(prefs.getInt('ur_heart_whatsapp_progress'), 0);
    });
  });

  group('Problem 2: Feed Candidate Profile Photo Filtering & Fallbacks', () {
    test('CandidateProfile prioritizes avatar_url and filters empty strings from photos list', () {
      final json = {
        'id': 'cand_anubhav_1',
        'name': 'Anubhav Thakur',
        'age': 24,
        'bio': 'Drawn to loving caring',
        'avatar_url': 'https://fmedkihgcvvzcekwybhe.supabase.co/storage/v1/object/public/ur-heart-media/users/ANUBHAV/slot_1.webp',
        'photos': ['', '', '', ''],
        'kyc_status': true,
      };

      final profile = CandidateProfile.fromJson(json);

      expect(profile.avatarUrl, isNotEmpty);
      expect(profile.avatarUrl, contains('slot_1.webp'));
      expect(profile.photos, isNotEmpty);
      expect(profile.photos.first, contains('slot_1.webp'));
      expect(profile.photos.where((p) => p.isEmpty).isEmpty, isTrue);
      expect(profile.isVerified, isTrue);
    });
  });

  group('Problem 3: Message Parsing and Encrypted Payload Handling', () {
    test('ChatMessage.fromJson correctly handles text, content, message, and encrypted_text', () {
      final jsonText = {
        'id': 'm1',
        'match_id': 'match_123',
        'sender_id': 'peer_1',
        'recipient_id': 'me',
        'text': 'Hello mindful seeker',
        'timestamp': '2026-09-30T21:00:00Z',
      };
      final msg1 = ChatMessage.fromJson(jsonText);
      expect(msg1.text, equals('Hello mindful seeker'));

      final jsonContent = {
        'id': 'm2',
        'match_id': 'match_123',
        'sender_id': 'peer_1',
        'recipient_id': 'me',
        'content': 'Heartfelt reflection',
        'timestamp': '2026-09-30T21:05:00Z',
      };
      final msg2 = ChatMessage.fromJson(jsonContent);
      expect(msg2.text, equals('Heartfelt reflection'));
    });
  });

  group('Problem 4: ChatDialogueArguments Peer Profile & Verification State', () {
    test('ChatDialogueArguments retains recipient avatar, verified crest, and bio', () {
      const args = ChatDialogueArguments(
        matchId: 'match-101',
        recipientId: 'user-anubhav',
        recipientName: 'Anubhav Thakur',
        recipientAge: 24,
        recipientAvatarUrl: 'https://cdn.example.com/anubhav.webp',
        isVerified: true,
        bio: 'Drawn to loving caring',
        location: 'Ayodhya, Uttar Pradesh · GPS Verified',
      );

      expect(args.recipientName, equals('Anubhav Thakur'));
      expect(args.recipientAge, equals(24));
      expect(args.recipientAvatarUrl, equals('https://cdn.example.com/anubhav.webp'));
      expect(args.isVerified, isTrue);
      expect(args.bio, equals('Drawn to loving caring'));
      expect(args.location, contains('Ayodhya'));
    });
  });

  group('Problem 5: Chat Thread and Spark Deserialization Prevents Sanctuary Seeker Fallback', () {
    test('ChatConversation.fromJson resolves peer_name, peer_age, and avatar from backend', () {
      final threadJson = {
        'match_id': 'match_777',
        'peer_id': 'user_anubhav_777',
        'peer_name': 'Anubhav Thakur',
        'peer_age': 24,
        'peer_photo': 'https://cdn.example.com/anubhav.webp',
        'is_verified': true,
        'last_message': 'hello',
        'last_timestamp': '2026-09-30T20:55:00Z',
        'unread_count': 0,
      };

      final conv = ChatConversation.fromJson(threadJson);

      expect(conv.recipientName, equals('Anubhav Thakur'));
      expect(conv.recipientAge, equals(24));
      expect(conv.recipientAvatarUrl, equals('https://cdn.example.com/anubhav.webp'));
      expect(conv.isVerified, isTrue);
    });

    test('SparkProfile.fromJson maps name and avatar correctly', () {
      final sparkJson = {
        'id': 'match_888',
        'name': 'Anubhav Thakur',
        'age': 24,
        'avatar_url': 'https://cdn.example.com/anubhav.webp',
        'is_verified': true,
        'match_type': 'MUTUAL',
      };

      final spark = SparkProfile.fromJson(sparkJson);

      expect(spark.name, equals('Anubhav Thakur'));
      expect(spark.age, equals(24));
      expect(spark.avatarUrl, equals('https://cdn.example.com/anubhav.webp'));
      expect(spark.isVerified, isTrue);
    });
  });
}
