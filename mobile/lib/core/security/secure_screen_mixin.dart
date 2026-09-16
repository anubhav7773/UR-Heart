import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Hardware Display Privacy Mixin (FLAG_SECURE)
/// Enforces hardware-level protection on sensitive routes (Feed, Chat, Photo Upload).
/// Disables screenshots, screen recording, and app-switcher background previews.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
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
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint('FLAG_SECURE enablement error: $e');
    }
  }

  Future<void> _disableScreenSecurity() async {
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint('FLAG_SECURE removal error: $e');
    }
  }
}
