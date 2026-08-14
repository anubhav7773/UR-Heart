import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlutterWindowManager {
  // ignore: constant_identifier_names
  static const int FLAG_SECURE = 8192;
  static const MethodChannel _channel = MethodChannel('flutter_windowmanager');

  static Future<bool> addFlags(int flags) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('addFlags', {'flags': flags});
        return res ?? false;
      } catch (e) {
        if (kDebugMode) print('FlutterWindowManager addFlags notice: $e');
        return false;
      }
    }
    return false;
  }

  static Future<bool> clearFlags(int flags) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('clearFlags', {'flags': flags});
        return res ?? false;
      } catch (e) {
        if (kDebugMode) print('FlutterWindowManager clearFlags notice: $e');
        return false;
      }
    }
    return false;
  }
}
