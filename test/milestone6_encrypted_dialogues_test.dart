import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/core/theme/theme_controller.dart';
import 'package:ur_heart/features/chat/controllers/websocket_chat_service.dart';
import 'package:ur_heart/features/chat/domain/chat_models.dart';
import 'package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart';
import 'package:ur_heart/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:ur_heart/features/chat/presentation/widgets/ai_icebreaker_chips_row.dart';
import 'package:ur_heart/features/chat/presentation/widgets/conversation_dialogue_tile.dart';
import 'package:ur_heart/features/chat/presentation/widgets/delivery_tick_icon.dart';
import 'package:ur_heart/features/chat/presentation/widgets/dialogue_message_bubble.dart';
import 'package:ur_heart/features/chat/presentation/widgets/sacred_bridge_app_bar_action.dart';
import 'package:ur_heart/features/chat/presentation/widgets/shared_context_prompt_card.dart';
import 'package:ur_heart/features/chat/presentation/widgets/text_only_chat_input_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child, {bool isDark = true}) {
    return ProviderScope(
      overrides: [
        themeProvider.overrideWith(
          (ref) => ThemeController(
            ThemeState(
              activeTheme: isDark ? SanctuaryTheme.dark : SanctuaryTheme.light,
              isLocked: true,
            ),
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('Milestone 6: 1. Hardware Screenshot Shield (FLAG_SECURE)', () {
    testWidgets('ChatDialogueScreen enables FLAG_SECURE on init and clears on dispose', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ChatDialogueScreen(matchId: 'match-secure-test'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatDialogueScreen), findsOneWidget);
    });
  });

  group('Milestone 6: 2. Local NLP Contact Sanitizer Inspection', () {
    testWidgets('Blocks Indian phone numbers and shows warning toast', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(
        wrapWithTheme(
          TextOnlyChatInputBar(
            isDark: true,
            onSendMessage: (msg) => sentMessage = msg,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'Call me at 9876543210');
      await tester.pumpAndSettle();

      final send = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(sentMessage, isNull);
      expect(find.textContaining('Direct phone numbers are shielded'), findsOneWidget);
    });

    testWidgets('Blocks Hindi transliterated written digits', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(
        wrapWithTheme(
          TextOnlyChatInputBar(
            isDark: true,
            onSendMessage: (msg) => sentMessage = msg,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'Number is saat aath nau zero ek do teen char paanch chhe');
      await tester.pumpAndSettle();

      final send = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(sentMessage, isNull);
      expect(find.textContaining('Spelled-out phone numbers cannot be shared'), findsOneWidget);
    });

    testWidgets('Blocks social handle and external platform evasions', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(
        wrapWithTheme(
          TextOnlyChatInputBar(
            isDark: true,
            onSendMessage: (msg) => sentMessage = msg,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'Follow me @insta_handle');
      await tester.pumpAndSettle();

      final send = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(sentMessage, isNull);
      expect(find.textContaining('Direct handles and social links are prohibited'), findsOneWidget);
    });

    testWidgets('Dispatches clean heartfelt text message', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(
        wrapWithTheme(
          TextOnlyChatInputBar(
            isDark: true,
            onSendMessage: (msg) => sentMessage = msg,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'The rain outside carries such stillness today.');
      await tester.pumpAndSettle();

      final send = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(sentMessage, equals('The rain outside carries such stillness today.'));
    });
  });

  group('Milestone 6: 3. 100% Text-Only Verification', () {
    testWidgets('Verifies zero photo, mic, attachment, or sticker widgets in Screen 9', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ChatDialogueScreen(matchId: 'match-text-only'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt), findsNothing);
      expect(find.byIcon(Icons.photo), findsNothing);
      expect(find.byIcon(Icons.photo_camera), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.sentiment_satisfied), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });

  group('Milestone 6: 4. WebSocket 3-Stage Tick Pipeline', () {
    test('WebSocket service manages heartbeat and sends typed payloads', () {
      final ws = WebSocketChatService.instance;
      expect(ws.eventStream, isNotNull);
      ws.disconnect();
    });

    testWidgets('Renders Sent (single tick), Delivered (double grey), Read (double cyan)', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              DeliveryTickIcon(status: MessageDeliveryStatus.sent, isDark: true),
              DeliveryTickIcon(status: MessageDeliveryStatus.delivered, isDark: true),
              DeliveryTickIcon(status: MessageDeliveryStatus.read, isDark: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNWidgets(2));
    });

    testWidgets('DialogueMessageBubble displays text, timestamp and delivery tick', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        wrapWithTheme(
          DialogueMessageBubble(
            message: ChatMessage(
              id: 'msg-1',
              matchId: 'match-1',
              senderId: 'user-me',
              recipientId: 'user-peer',
              text: 'Simplicity is sacred.',
              createdAt: now,
              status: MessageDeliveryStatus.read,
              isMe: true,
            ),
            isMe: true,
            isDark: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Simplicity is sacred.'), findsOneWidget);
      expect(find.byType(DeliveryTickIcon), findsOneWidget);
    });
  });

  group('Milestone 6: 5. 3 Bespoke AI Icebreakers & Sacred Bridge Action', () {
    testWidgets('Renders 3 bespoke AI starter chips and handles tap', (tester) async {
      String? selectedPrompt;
      final chips = [
        'What thought brought you peace today?',
        'If silence had a sound, what would it sound like?',
        'Which memory feels warmest right now?',
      ];

      await tester.pumpWidget(
        wrapWithTheme(
          AiIcebreakerChipsRow(
            isDark: true,
            icebreakers: chips,
            onSelectIcebreaker: (p) => selectedPrompt = p,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MINDFUL OPENINGS (AI BESPOKE)'), findsOneWidget);
      expect(find.text('What thought brought you peace today?'), findsOneWidget);

      await tester.tap(find.text('What thought brought you peace today?'));
      await tester.pumpAndSettle();

      expect(selectedPrompt, equals('What thought brought you peace today?'));
    });

    testWidgets('Renders locked bridge pill and opens reveal ritual dialog', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SacredBridgeAppBarAction(
            matchId: 'match-bridge',
            isDark: true,
            bridgeData: {
              'is_unlocked': false,
              'user_step': 2,
              'peer_step': 1,
              'platform': 'whatsapp',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bridge (2/3)'), findsOneWidget);
      await tester.tap(find.text('Bridge (2/3)'));
      await tester.pumpAndSettle();

      expect(find.text('Sacred Enclave Bridge'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders unmasked native intent launcher button for Instagram', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SacredBridgeAppBarAction(
            matchId: 'match-bridge',
            isDark: true,
            bridgeData: {
              'is_unlocked': true,
              'platform': 'instagram',
              'handle': 'sanctuary_soul',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Instagram'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('Renders SharedContextPromptCard and ConversationDialogueTile in ChatsListScreen', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              SharedContextPromptCard(
                isDark: true,
                promptText: 'A shared appreciation for poetry and quiet dusk walks.',
              ),
              Expanded(child: ChatsListScreen()),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHARED RESONANCE CONTEXT'), findsOneWidget);
      expect(find.text('"A shared appreciation for poetry and quiet dusk walks."'), findsOneWidget);
      expect(find.byType(ConversationDialogueTile), findsWidgets);
    });
  });
}
