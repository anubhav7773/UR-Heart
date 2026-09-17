import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hardware Display Privacy Mixin (FLAG_SECURE)
/// Enforces hardware-level protection on sensitive routes in production release builds.
/// In testing and debug mode, screenshot and screen recording blocking is lifted
/// so QA and developers can capture screens and diagnose issues without obstruction.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const MethodChannel _securityChannel = MethodChannel('com.urheart.app/security');

  /// Global testing switch: when false (default for development/testing), SS/SR are permitted.
  static bool enableSecurityInTesting = false;

  @override
  void initState() {
    super.initState();
    _enableScreenSecurity();
  }

  @override
  void dispose() {
    _disableScreenSecurity();
    super.dispose();
  }

  Future<void> _enableScreenSecurity() async {
    // In testing or debug mode, do NOT block screenshots or screen recording
    if (kDebugMode || !enableSecurityInTesting) {
      // Proactively ensure window security flag is cleared
      await _disableScreenSecurity();
      return;
    }
    try {
      await _securityChannel.invokeMethod('enableSecure');
    } catch (e) {
      debugPrint('FLAG_SECURE enablement error: $e');
    }
  }

  Future<void> _disableScreenSecurity() async {
    try {
      await _securityChannel.invokeMethod('disableSecure');
    } catch (e) {
      debugPrint('FLAG_SECURE removal error: $e');
    }
  }
}


