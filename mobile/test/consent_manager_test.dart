import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/ads/services/consent_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConsentManager singleton initializes without throwing exceptions', () {
    final manager = ConsentManager.instance;
    expect(manager, isNotNull);
  });
}
