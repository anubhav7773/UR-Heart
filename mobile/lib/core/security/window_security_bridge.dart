import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowSecurityBridge {
  WindowSecurityBridge._internal();
  static final WindowSecurityBridge instance = WindowSecurityBridge._internal();

  static const MethodChannel _channel = MethodChannel('com.asi.urheart/window_security');
  bool _isSecured = false;
  bool get isSecured => _isSecured;

  /// Hardware screenshot & screen recording block enable karta hai (Normal users & private chats)
  Future<void> enable() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('enableSecure');
      _isSecured = true;
      debugPrint("🛡️ [WindowSecurity] Native FLAG_SECURE ENABLED.");
    } catch (e) {
      debugPrint("⚠️ [WindowSecurity] Error enabling native security: $e");
    }
  }

  /// Master Admin Audit ke liye FLAG_SECURE ko instantly unblock karta hai
  Future<void> disableForAdminAudit() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('disableSecure');
      _isSecured = false;
      debugPrint("🔓 [WindowSecurity] Native FLAG_SECURE DISABLED (Admin Audit Mode).");
    } catch (e) {
      debugPrint("⚠️ [WindowSecurity] Error disabling native security: $e");
    }
  }
}
