import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/network/api_client.dart';
import 'package:ur_heart/features/ai_sanctuary/data/ai_sanctuary_repository.dart';
import 'package:ur_heart/features/ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart';
import 'package:ur_heart/features/ai_sanctuary/presentation/widgets/ai_dialogue_coach_sheet.dart';
import 'package:ur_heart/features/ai_sanctuary/presentation/widgets/ai_grievance_assistant_sheet.dart';

class MockAiSanctuaryRepository extends AiSanctuaryRepository {
  MockAiSanctuaryRepository() : super(ApiClient());

  @override
  Future<Map<String, dynamic>> chatWithEva({
    required String message,
    List<Map<String, String>>? history,
    Map<String, dynamic>? context,
  }) async {
    return {
      'reply':
          'Namaste. Mujhe Asiverticals ne banaya hai. Main aapki mindful companion hoon.',
      'is_guarded': false,
      'status': 'success',
    };
  }

  @override
  Future<String> getDialogueCoaching({
    required String partnerName,
    required String lastIncomingMessage,
    String? userDraftReply,
  }) async {
    return '1) Curious: What inspired your love for Sunday mornings?\n2) Grounded: That brings a calm smile to my day.';
  }

  @override
  Future<String> assistGrievanceFiling({
    required String offenderName,
    required String userNarrative,
  }) async {
    return 'Your emotional safety is protected. Under IT Rules 2021 Rule 3(2), this incident is categorized as Harassment.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAiSanctuaryRepository mockRepo;

  setUp(() {
    mockRepo = MockAiSanctuaryRepository();
  });

  group('Eva AI Sanctuary Frontend Suite Verification', () {
    testWidgets(
        'EvaSanctuaryScreen renders glowing orb, Asiverticals attribution, and prompt chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSanctuaryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: EvaSanctuaryScreen(animateOrb: false),
          ),
        ),
      );
      await tester.pump();

      // Verify header and creator attribution
      expect(find.text('Eva Sanctuary'), findsOneWidget);
      expect(find.text('Mindful AI by Asiverticals'), findsOneWidget);

      // Verify welcoming greeting with Asiverticals attribution
      expect(
        find.textContaining(
            'Asiverticals dwara banayi gayi aapki mindful AI companion'),
        findsOneWidget,
      );

      // Verify Sacred Resonance Space orb
      expect(find.text('Sacred Resonance Space'), findsOneWidget);

      // Verify quick action chips
      expect(
          find.text('How should I reply to my match without sounding eager?'),
          findsOneWidget);

      // Verify text input field and send button
      expect(find.byType(TextField), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'AiDialogueCoachSheet renders partner quote and Asiverticals attribution',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSanctuaryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AiDialogueCoachSheet(
                partnerName: 'Ananya',
                lastIncomingMessage:
                    'I love slow Sunday mornings with hot tea.',
                onApplyReply: (_) {},
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Eva Dialogue Wingman'), findsOneWidget);
      expect(find.text('Authentic communication coach by Asiverticals'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Ananya: "I love slow Sunday mornings with hot tea."'),
          findsOneWidget);
      expect(find.text('Mindful Guidance & Reply Ideas:'), findsOneWidget);
      expect(find.text('Polish'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'AiGrievanceAssistantSheet renders IT Rules 2021 assistance and Asiverticals attribution',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSanctuaryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiGrievanceAssistantSheet(
                offenderName: 'Rohan',
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Eva Safety & Grievance Concierge'), findsOneWidget);
      expect(find.text('Statutory Reporting Assistant by Asiverticals'),
          findsOneWidget);
      expect(find.textContaining('IT Rules 2021'), findsOneWidget);
      expect(find.text('Analyze & Guide My Report'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
