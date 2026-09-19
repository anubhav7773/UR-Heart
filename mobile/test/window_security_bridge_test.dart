import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/core/security/window_security_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.asi.urheart/window_security'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        return true;
      },
    );
    log.clear();
  });

  test('WindowSecurityBridge sends enableSecure and disableSecure to native platform', () async {
    final bridge = WindowSecurityBridge.instance;

    await bridge.enable();
    expect(log.last.method, 'enableSecure');
    expect(bridge.isSecured, isTrue);

    await bridge.disableForAdminAudit();
    expect(log.last.method, 'disableSecure');
    expect(bridge.isSecured, isFalse);
  });
}
