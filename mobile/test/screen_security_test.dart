import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/security/screen_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.asi.urheart/window_security'),
      (MethodCall methodCall) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('screen_protector'),
      (MethodCall methodCall) async => true,
    );
  });

  test('ScreenSecurityService toggles active state correctly', () async {
    final service = ScreenSecurityService.instance;

    await service.enableProtection();
    expect(service.isProtectionActive, isTrue);

    await service.disableProtectionForAdminAudit();
    expect(service.isProtectionActive, isFalse);

    await service.enableProtection();
    expect(service.isProtectionActive, isTrue);
  });
}
