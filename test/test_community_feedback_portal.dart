import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ur_heart/core/services/sentry_service.dart';
import 'package:ur_heart/features/settings/presentation/widgets/community_feedback_card.dart';
import 'package:ur_heart/features/settings/presentation/widgets/sanctuary_feedback_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Community Feedback & Bug Reporting Portal Tests', () {
    testWidgets('CommunityFeedbackCard renders with direct badge and opens bottom sheet', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityFeedbackCard(isDark: true),
              ),
            ),
          ),
        ),
      );

      // Verify Card elements
      expect(find.text('Feedback & Bug Report'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);

      // Tap card to open modal sheet
      await tester.tap(find.text('Feedback & Bug Report'));
      await tester.pumpAndSettle();

      // Verify Bottom sheet opened
      expect(find.byType(SanctuaryFeedbackSheet), findsOneWidget);
      expect(find.text('Community Feedback & Bug Portal'), findsOneWidget);
      expect(find.text('🐞 Bug Report'), findsOneWidget);
      expect(find.text('💡 Suggest Feature'), findsOneWidget);
      expect(find.text('🎨 UI & Design'), findsOneWidget);
      expect(find.text('💬 General Thought'), findsOneWidget);
    });

    testWidgets('SanctuaryFeedbackSheet validation prevents submitting empty description', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SanctuaryFeedbackSheet(),
            ),
          ),
        ),
      );

      // Attempt to submit with empty field
      await tester.tap(find.text('Submit to Sanctuary Team'));
      await tester.pump();

      expect(find.text('Please describe your bug or suggestion.'), findsOneWidget);
    });

    testWidgets('SanctuaryFeedbackSheet category switching updates state smoothly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SanctuaryFeedbackSheet(),
            ),
          ),
        ),
      );

      // Switch category to Feature Idea
      await tester.tap(find.text('💡 Suggest Feature'));
      await tester.pump();

      // Enter valid feedback
      await tester.enterText(
        find.byType(TextField),
        'It would be great to have a playlist sharing resonance card.',
      );
      await tester.pump();

      expect(
        find.text('It would be great to have a playlist sharing resonance card.'),
        findsOneWidget,
      );
    });

    test('SentryService.captureUserFeedback executes without throwing', () async {
      // Must execute gracefully even when Sentry is uninitialized or in test environment
      await expectLater(
        SentryService.captureUserFeedback(
          category: 'bug_report',
          description: 'Automated test simulated UI glitch',
          diagnostics: {'os': 'TestRunner', 'version': '1.0.0'},
        ),
        completes,
      );
    });
  });
}
