import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hardware Display Privacy Mixin (FLAG_SECURE)
/// Enforces hardware-level protection on sensitive routes (Feed, Chat, Photo Upload).
/// Disables screenshots, screen recording, and app-switcher background previews.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const MethodChannel _securityChannel = MethodChannel('com.urheart.app/security');

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

