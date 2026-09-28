import 'package:flutter/services.dart';

/// Native Flutter Window Manager for FLAG_SECURE hardware screenshot protection
/// Completely replaces obsolete third-party library with native MethodChannel
class FlutterWindowManager {
  FlutterWindowManager._();

  // ignore: constant_identifier_names
  static const int FLAG_SECURE = 8192;
  static const MethodChannel _channel = MethodChannel('flutter_windowmanager');

  static Future<bool> addFlags(int flags) async {
    try {
      final res = await _channel.invokeMethod<bool>('addFlags', {'flags': flags});
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearFlags(int flags) async {
    try {
      final res = await _channel.invokeMethod<bool>('clearFlags', {'flags': flags});
      return res ?? true;
    } catch (_) {
      return false;
    }
  }
}
