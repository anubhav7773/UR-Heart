import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'window_security_bridge.dart';

class ScreenSecurityService {
  ScreenSecurityService._internal();
  static final ScreenSecurityService instance = ScreenSecurityService._internal();

  bool _isProtectionActive = false;
  bool get isProtectionActive => _isProtectionActive;

  /// Enables app-wide screenshot and screen recording blocking.
  /// On Android, sets WindowManager.LayoutParams.FLAG_SECURE.
  /// On iOS, masks recent app previews and blacks out screen recordings.
  Future<void> enableProtection() async {
    try {
      if (kIsWeb) return;
      _isProtectionActive = true;
      await WindowSecurityBridge.instance.enable();
      await ScreenProtector.preventScreenshotOn();
      if (!kIsWeb && Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithColor(const Color(0xFF0A0A0D));
      }
      debugPrint("🛡️ ScreenSecurityService: Hardware protection ENABLED (FLAG_SECURE active).");
    } catch (e) {
      debugPrint("⚠️ ScreenSecurityService error enabling protection: $e");
    }
  }

  /// Disables protection strictly for authorized Super Admin audit sessions.
  Future<void> disableProtectionForAdminAudit() async {
    try {
      if (kIsWeb) return;
      _isProtectionActive = false;
      await WindowSecurityBridge.instance.disableForAdminAudit();
      await ScreenProtector.preventScreenshotOff();
      debugPrint("🔓 ScreenSecurityService: Hardware protection temporarily DISABLED for Admin Audit.");
    } catch (e) {
      debugPrint("⚠️ ScreenSecurityService error disabling protection: $e");
    }
  }
}
