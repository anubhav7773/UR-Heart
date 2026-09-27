import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/core/theme/theme_controller.dart';
import 'package:ur_heart/features/chat/domain/nlp_chat_sanitizer.dart';
import 'package:ur_heart/features/chat/data/chat_websocket_service.dart';
import 'package:ur_heart/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';
import 'package:ur_heart/features/chat/presentation/widgets/delivery_tick_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NLP Chat Sanitizer Gatekeeper Tests', () {
    test('Allows wholesome, thoughtful text without contact leaks', () {
      final res = NlpChatSanitizer.inspect('The quiet chapters of life always speak the loudest.');
      expect(res.isValid, isTrue);
      expect(res.violationCode, isNull);
    });

    test('Blocks standard 10-digit Indian mobile numbers', () {
      final res1 = NlpChatSanitizer.inspect('Call me at 9876543210 tomorrow.');
      expect(res1.isValid, isFalse);
      expect(res1.violationCode, equals('PHONE_NUMBER_DETECTED'));

      final res2 = NlpChatSanitizer.inspect('+91 98765 43210 is my number');
      expect(res2.isValid, isFalse);
      expect(res2.violationCode, equals('PHONE_NUMBER_DETECTED'));
    });

    test('Blocks Hindi & English transliterated written numbers', () {
      final res = NlpChatSanitizer.inspect(
        'Mera number hai nau aath saat chhe paanch char teen do ek shunya',
      );
      expect(res.isValid, isFalse);
      expect(res.violationCode, equals('TRANSLITERATED_PHONE_NUMBER_DETECTED'));
    });

    test('Blocks social platform keyword evasions', () {
      final resWhatsApp = NlpChatSanitizer.inspect('Let us talk on whatsapp instead');
      expect(resWhatsApp.isValid, isFalse);
      expect(resWhatsApp.violationCode, equals('SOCIAL_PLATFORM_KEYWORD_DETECTED'));

      final resInstagram = NlpChatSanitizer.inspect('Dm me on Instagram!');
      expect(resInstagram.isValid, isFalse);
      expect(resInstagram.violationCode, equals('SOCIAL_PLATFORM_KEYWORD_DETECTED'));
    });

    test('Blocks social handles and prefix evasions', () {
      final res = NlpChatSanitizer.inspect('Reach me at @mindful_poet');
      expect(res.isValid, isFalse);
      expect(res.violationCode, equals('SOCIAL_HANDLE_PREFIX_DETECTED'));
    });

    test('Blocks external links and email addresses', () {
      final resLink = NlpChatSanitizer.inspect('Check out https://my-portfolio.com');
      expect(resLink.isValid, isFalse);
      expect(resLink.violationCode, equals('EXTERNAL_LINK_OR_EMAIL_DETECTED'));

      final resEmail = NlpChatSanitizer.inspect('Write to me at poet@sanctuary.app');
      expect(resEmail.isValid, isFalse);
      expect(resEmail.violationCode, equals('EXTERNAL_LINK_OR_EMAIL_DETECTED'));
    });

    test('Blocks UPI Virtual Payment Addresses', () {
      final resUpi = NlpChatSanitizer.inspect('Send contribution to sanctuary@okhdfcbank');
      expect(resUpi.isValid, isFalse);
      expect(resUpi.violationCode, equals('UPI_PAYMENT_HANDLE_DETECTED'));
    });
  });

  group('WebSocket Service Lifecycle Tests', () {
    test('Initializes with default keep-alive heartbeat and disposes cleanly', () {
      final ws = ChatWebSocketService();
      expect(ws.eventStream, isNotNull);
      ws.dispose();
    });
  });

  group('Screen 8: Chats Hub Widget Tests', () {
    Widget createChatsListApp() {
      return ProviderScope(
        overrides: [
          themeProvider.overrideWith(
            (ref) => ThemeController(const ThemeState(activeTheme: SanctuaryTheme.dark, isLocked: true)),
          ),
        ],
        child: MaterialApp(
          routes: {
            ChatsListScreen.routeName: (context) => const ChatsListScreen(),
            ChatDialogueScreen.routeName: (context) => const ChatDialogueScreen(),
          },
          home: const ChatsListScreen(),
        ),
      );
    }

    testWidgets('Renders hub title, metrics pill, sparks carousel, and active dialogue list',
        (tester) async {
      await tester.pumpWidget(createChatsListApp());
      await tester.pumpAndSettle();

      expect(find.text('Mindful Dialogues'), findsOneWidget);
      expect(find.textContaining('ACTIVE DIALOGUES'), findsOneWidget);
      expect(find.text('Recent Sparks ✨'), findsOneWidget);
      expect(find.text('Aarav Sharma, 27'), findsOneWidget);
      expect(find.text('Meera Sen, 25'), findsOneWidget);
    });

    testWidgets('Filters conversations when search query is entered', (tester) async {
      await tester.pumpWidget(createChatsListApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Meera');
      await tester.pumpAndSettle();

      expect(find.text('Meera Sen, 25'), findsOneWidget);
      expect(find.text('Aarav Sharma, 27'), findsNothing);
    });

    testWidgets('Tapping a dialogue item navigates to Screen 9', (tester) async {
      await tester.pumpWidget(createChatsListApp());
      await tester.pumpAndSettle();

      final meeraTile = find.text('Meera Sen, 25');
      expect(meeraTile, findsOneWidget);
      await tester.tap(meeraTile);
      await tester.pumpAndSettle();

      // Screen 9 should now be rendered
      expect(find.text('Meera Sen, 25'), findsOneWidget);
      expect(find.text('WA Key ✓'), findsOneWidget);
    });
  });

  group('Screen 9: 1:1 Encrypted Dialogue Widget Tests', () {
    Widget createChatDialogueApp() {
      return ProviderScope(
        overrides: [
          themeProvider.overrideWith(
            (ref) => ThemeController(const ThemeState(activeTheme: SanctuaryTheme.dark, isLocked: true)),
          ),
        ],
        child: const MaterialApp(
          home: ChatDialogueScreen(),
        ),
      );
    }

    testWidgets('Screen 9 has 0 photo, mic, attachment, or sticker buttons (100% TEXT ONLY)',
        (tester) async {
      await tester.pumpWidget(createChatDialogueApp());
      await tester.pumpAndSettle();

      // Verify no media icons exist
      expect(find.byIcon(Icons.camera_alt), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
      expect(find.byIcon(Icons.photo), findsNothing);
      expect(find.byIcon(Icons.sentiment_satisfied), findsNothing);

      // Verify text input and send arrow exist
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('Renders shared context card and WhatsApp tick indicators', (tester) async {
      await tester.pumpWidget(createChatDialogueApp());
      await tester.pumpAndSettle();

      expect(find.text('SHARED RESONANCE CONTEXT'), findsOneWidget);
      expect(find.textContaining('Haruki Murakami'), findsOneWidget);
      expect(find.byType(DeliveryTickIcon), findsWidgets);
    });

    testWidgets('Valid message sends and appears in chat stream', (tester) async {
      await tester.pumpWidget(createChatDialogueApp());
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Finding silence amidst the busy city is truly grounding.');
      await tester.pumpAndSettle();

      final sendBtn = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Finding silence amidst the busy city is truly grounding.'), findsOneWidget);
    });

    testWidgets('Blocked message with phone number triggers NLP warning dialog', (tester) async {
      await tester.pumpWidget(createChatDialogueApp());
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Call me on 9876543210');
      await tester.pumpAndSettle();

      final sendBtn = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Dialogue warning modal must appear
      expect(find.text('Off-Platform Boundary'), findsOneWidget);
      expect(find.textContaining('Sharing phone numbers is strictly shielded'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Understood · Keep in Sanctuary'));
      await tester.pumpAndSettle();

      expect(find.text('Off-Platform Boundary'), findsNothing);
    });
  });
}
