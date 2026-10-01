import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur_heart/features/resonances/domain/resonance_models.dart';
import 'package:ur_heart/features/chat/presentation/controllers/chat_dialogue_controller.dart';
import 'package:ur_heart/features/chat/data/chat_repository.dart';
import 'package:ur_heart/features/chat/data/chat_websocket_service.dart';

class FailingChatRepository implements ChatRepository {

  @override
  Future<List<ChatMessage>> fetchThreadMessages(String matchId, {int limit = 50}) async {
    throw Exception('Simulated network failure on fetchThreadMessages');
  }

  @override
  Future<Map<String, dynamic>> fetchContactBridgeStatus(String matchId) async {
    return {'is_unlocked': false, 'platform': 'whatsapp', 'handle': '', 'has_wa_key': false, 'user_step': 1};
  }

  @override
  Future<Map<String, dynamic>> fetchPeerProfile(String matchId) async {
    return {'full_name': 'Meera Sen', 'avatar_url': 'https://urheart.app/p.jpg'};
  }

  @override
  Future<void> markMessagesAsRead(String matchId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebSocketService implements ChatWebSocketService {
  @override
  Stream<Map<String, dynamic>> get messageStream => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get eventStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sanctuary_seen_notification_ids': ['notif_1', 'notif_2'],
    });
  });

  group('Issue 4: Direct Letter Dialogue ID Cleaning & Resilient Loading', () {
    test('ChatDialogueController.cleanMatchId strips conn_, match-, and spark_ prefixes', () {
      const rawUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      expect(ChatDialogueController.cleanMatchId(rawUuid), rawUuid);
      expect(ChatDialogueController.cleanMatchId('conn_$rawUuid'), rawUuid);
      expect(ChatDialogueController.cleanMatchId('match-$rawUuid'), rawUuid);
      expect(ChatDialogueController.cleanMatchId('spark_$rawUuid'), rawUuid);
      expect(ChatDialogueController.cleanMatchId('match_$rawUuid'), rawUuid);
    });

    test('ChatDialogueController recovers from fetch error and does not stay in isLoading: true', () async {
      final fakeRepo = FailingChatRepository();
      final fakeWs = FakeWebSocketService();
      final controller = ChatDialogueController(
        fakeWs,
        fakeRepo,
        'user-me',
        'conn_a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      );

      // Clean matchId should have prefix removed
      expect(controller.state.matchId, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');

      await controller.initializeDialogue();

      // Must complete and set isLoading to false despite repository failure
      expect(controller.state.isLoading, isFalse);
    });
  });

  group('Issue 5: Resonance Tab Models Categorization', () {
    test('IncomingLikeProfile parses direct letter attributes cleanly', () {
      final jsonDirect = {
        'id': 'like_123',
        'sender_id': 'user_1',
        'full_name': 'Meera Sen',
        'age': 24,
        'photo_url': 'https://urheart.app/meera.webp',
        'swipe_type': 'direct',
        'is_direct_letter': true,
        'category_tag': 'Direct Letter',
        'letter_snippet': 'Direct Sanctuary Letter 💌',
      };
      final profile = IncomingLikeProfile.fromJson(jsonDirect);

      expect(profile.isDirectLetter, isTrue);
      expect(profile.swipeType, 'direct');
      expect(profile.categoryTag, 'Direct Letter');
      expect(profile.letterSnippet, contains('Direct Sanctuary Letter'));
    });

    test('MutualConnection parses Direct Letter vs Mutual Resonance', () {
      final jsonMutual = {
        'id': 'conn_1',
        'match_id': 'match_uuid_1',
        'partner_id': 'partner_1',
        'full_name': 'Aarav Sharma',
        'age': 26,
        'category_tag': 'Direct Letter',
        'is_direct_letter': true,
        'last_snippet': 'A thoughtful sacred letter.',
      };
      final connection = MutualConnection.fromJson(jsonMutual);

      expect(connection.isDirectLetter, isTrue);
      expect(connection.categoryTag, 'Direct Letter');
      expect(connection.matchId, 'match_uuid_1');
    });
  });

  group('Issue 6: Persistent Notification Deduplication', () {
    test('Seen notification IDs are read from and written to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final seenList = prefs.getStringList('sanctuary_seen_notification_ids') ?? [];

      expect(seenList, contains('notif_1'));
      expect(seenList, contains('notif_2'));

      seenList.add('notif_3');
      await prefs.setStringList('sanctuary_seen_notification_ids', seenList);

      final updated = prefs.getStringList('sanctuary_seen_notification_ids');
      expect(updated, hasLength(3));
      expect(updated, contains('notif_3'));
    });
  });
}
