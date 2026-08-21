import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment _currentEnv = kReleaseMode ? Environment.production : Environment.development;
  static String? _customBaseUrl;

  /// Current active environment
  static Environment get currentEnvironment => _currentEnv;

  /// Switch the active environment programmatically
  static void setEnvironment(Environment env) {
    _currentEnv = env;
    _customBaseUrl = null;
    if (kDebugMode) {
      print('🌐 [EnvironmentConfig] Switched environment to: ${env.name} (BaseUrl: $baseUrl)');
    }
  }

  /// Override with a custom base URL (e.g. for testing on physical devices on local Wi-Fi)
  static void setCustomBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (kDebugMode) {
      print('🌐 [EnvironmentConfig] Custom base URL set to: $_customBaseUrl');
    }
  }

  /// Development base URL resolving local host according to platform:
  /// - Android Emulator: http://10.0.2.2:8000/api/v1
  /// - iOS Simulator / macOS / Windows / Linux: http://localhost:8000/api/v1
  /// - Web: http://127.0.0.1:8000/api/v1
  static String get devBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:8000/api/v1';
  }

  /// Staging environment base URL
  static const String stagingBaseUrl = 'https://staging.ur-heart.com/api/v1';

  /// Production environment base URL (FastAPI backend on Render/Cloud)
  static const String productionBaseUrl = 'https://ur-heart.onrender.com/api/v1';

  /// Resolves the current base URL
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    switch (_currentEnv) {
      case Environment.development:
        return devBaseUrl;
      case Environment.staging:
        return stagingBaseUrl;
      case Environment.production:
        return productionBaseUrl;
    }
  }

  /// Resolves matching WebSocket endpoint for real-time chat
  static String get wsBaseUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return httpUrl.replaceFirst('https://', 'wss://').replaceAll('/api/v1', '');
    } else if (httpUrl.startsWith('http://')) {
      return httpUrl.replaceFirst('http://', 'ws://').replaceAll('/api/v1', '');
    }
    return 'wss://ur-heart.onrender.com';
  }
}
