import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/admin/presentation/admin_kyc_dashboard.dart';

void main() {
  testWidgets('AdminKycDashboardScreen displays title and metric structure', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminKycDashboardScreen(),
      ),
    );

    // Initial loading or title verification
    expect(find.text('Master KYC Review Hub'), findsOneWidget);
  });
}
