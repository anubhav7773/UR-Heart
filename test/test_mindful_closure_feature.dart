import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/chat/domain/chat_models.dart';
import 'package:ur_heart/features/chat/presentation/widgets/conversation_dialogue_tile.dart';

void main() {
  group('Mindful Closure Domain & Models Tests', () {
    test('ChatConversation parses closure fields and getters correctly', () {
      final jsonClosed = {
        'match_id': 'match-test-123',
        'recipient_id': 'user-456',
        'recipient_name': 'Ananya',
        'recipient_age': 25,
        'recipient_avatar_url': '',
        'is_online': true,
        'has_wa_key': false,
        'last_message_text': 'Wishing you stillness and joy ahead.',
        'last_message_timestamp': DateTime.now().toIso8601String(),
        'unread_count': 0,
        'category_tag': 'Mutual Spark',
        'closure_status': 'closed_with_grace',
        'closed_by_user_id': 'user-me',
        'closed_at': DateTime.now().toIso8601String(),
        'closure_template_key': 'silent_bow',
        'closure_note': 'Wishing you stillness and joy ahead.',
      };

      final convClosed = ChatConversation.fromJson(jsonClosed);
      expect(convClosed.isClosed, isTrue);
      expect(convClosed.isStagnant, isFalse);
      expect(convClosed.closureStatus, equals('closed_with_grace'));
      expect(convClosed.closureTemplateKey, equals('silent_bow'));
      expect(convClosed.closureNote, equals('Wishing you stillness and joy ahead.'));

      final jsonStagnant = {
        'match_id': 'match-test-789',
        'recipient_id': 'user-789',
        'recipient_name': 'Rohan',
        'recipient_age': 27,
        'recipient_avatar_url': '',
        'is_online': false,
        'has_wa_key': false,
        'last_message_text': 'Hey, how was your weekend?',
        'last_message_timestamp': DateTime.now().subtract(const Duration(hours: 50)).toIso8601String(),
        'unread_count': 0,
        'category_tag': 'Mutual Spark',
        'closure_status': 'stagnant',
      };

      final convStagnant = ChatConversation.fromJson(jsonStagnant);
      expect(convStagnant.isClosed, isFalse);
      expect(convStagnant.isStagnant, isTrue);
      expect(convStagnant.closureStatus, equals('stagnant'));
    });

    test('MindfulClosureTemplate parses JSON correctly', () {
      final json = {
        'key': 'wavelength',
        'title': 'Different Wavelengths',
        'icon': '🌊',
        'message': 'Thank you for sharing your time with me.',
      };

      final template = MindfulClosureTemplate.fromJson(json);
      expect(template.key, equals('wavelength'));
      expect(template.title, equals('Different Wavelengths'));
      expect(template.icon, equals('🌊'));
      expect(template.message, equals('Thank you for sharing your time with me.'));
    });
  });

  group('ConversationDialogueTile Mindful Badges Widget Tests', () {
    testWidgets('Renders "Past Reflection 🍃" badge when conversation is closed', (tester) async {
      final closedConv = ChatConversation(
        matchId: 'match-1',
        recipientId: 'user-1',
        recipientName: 'Kavya',
        recipientAge: 24,
        recipientAvatarUrl: '',
        isOnline: false,
        hasWaKey: false,
        lastMessageText: 'Farewell note with grace',
        lastMessageTimestamp: DateTime.now(),
        lastMessageStatus: MessageDeliveryStatus.read,
        unreadCount: 0,
        categoryTag: 'Mutual Spark',
        sharedContextQuote: 'Sacred match',
        closureStatus: 'closed_with_grace',
        closureNote: 'Farewell note with grace',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationDialogueTile(
              conversation: closedConv,
              isDark: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Past Reflection 🍃'), findsOneWidget);
      expect(find.text('Kavya, 24'), findsOneWidget);
    });

    testWidgets('Renders "Quiet Tide ⏳" badge when conversation is stagnant', (tester) async {
      final stagnantConv = ChatConversation(
        matchId: 'match-2',
        recipientId: 'user-2',
        recipientName: 'Aarav',
        recipientAge: 26,
        recipientAvatarUrl: '',
        isOnline: true,
        hasWaKey: false,
        lastMessageText: 'Let us reconnect soon',
        lastMessageTimestamp: DateTime.now().subtract(const Duration(hours: 49)),
        lastMessageStatus: MessageDeliveryStatus.delivered,
        unreadCount: 0,
        categoryTag: 'Mutual Spark',
        sharedContextQuote: 'Quiet match',
        closureStatus: 'stagnant',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationDialogueTile(
              conversation: stagnantConv,
              isDark: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Quiet Tide ⏳'), findsOneWidget);
      expect(find.text('Mutual Spark'), findsOneWidget);
      expect(find.text('Aarav, 26'), findsOneWidget);
    });
  });
}
