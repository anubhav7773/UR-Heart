import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/chat/presentation/direct_chat_screen.dart';

void main() {
  testWidgets('DirectChatScreen renders correctly with participant details', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DirectChatScreen(
          matchId: '00000000-0000-0000-0000-000000000001',
          recipientId: '00000000-0000-0000-0000-000000000002',
          recipientName: 'Priya Sharma',
        ),
      ),
    );

    // Verify participant name and UI presence
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // Advance fake timer to drain socket / Dio connect timers
    await tester.pump(const Duration(seconds: 35));
  });
}
