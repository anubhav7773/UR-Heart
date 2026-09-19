import 'package:flutter/material.dart';
import 'screen_security_service.dart';

/// Hardware Display Privacy Mixin (FLAG_SECURE)
/// Enforces hardware-level protection on sensitive routes.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    _enableScreenSecurity();
  }

  Future<void> _enableScreenSecurity() async {
    await ScreenSecurityService.instance.enableProtection();
  }
}



