import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../network/user_repository.dart';
import '../security/storage_manager.dart';

/// Represents the status and payload of a captured OAuth deep link callback.
class OAuthCallbackEvent {
  final Uri rawUri;
  final bool isSuccess;
  final String? code;
  final String? sessionToken;
  final String? createdSessionId;
  final String? state;
  final String? error;
  final String? errorDescription;

  OAuthCallbackEvent({
    required this.rawUri,
    required this.isSuccess,
    this.code,
    this.sessionToken,
    this.createdSessionId,
    this.state,
    this.error,
    this.errorDescription,
  });

  @override
  String toString() {
    return 'OAuthCallbackEvent(isSuccess: $isSuccess, code: ${code != null ? '***' : null}, sessionToken: ${sessionToken != null ? '***' : null}, error: $error)';
  }
}

/// Production-grade Deep Link & Universal Link OAuth Redirect Handler.
/// Manages cold-start (app opened from deep link) and warm-state (app in memory)
/// OAuth redirect captures (`clerk://oauth_callback?...`).
class OAuthRedirectHandler {
  static final OAuthRedirectHandler instance = OAuthRedirectHandler._internal();
  factory OAuthRedirectHandler() => instance;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final _callbackController = StreamController<OAuthCallbackEvent>.broadcast();

  /// Stream of validated OAuth callback events for UI screens & Bloc/Providers
  Stream<OAuthCallbackEvent> get onOAuthCallback => _callbackController.stream;

  bool _isInitialized = false;
  String? _lastProcessedUri;

  OAuthRedirectHandler._internal();

  /// Initializes deep link listeners. Should be called early in `main.dart` or root App widget.
  Future<void> initialize({
    Function(OAuthCallbackEvent event)? onCallbackReceived,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (onCallbackReceived != null) {
      _callbackController.stream.listen(onCallbackReceived);
    }

    // 1. Cold Start Check: App launched directly from OAuth Deep Link
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (kDebugMode) {
          print('📱 [OAuthRedirectHandler] Cold start link detected: $initialUri');
        }
        await _processUri(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [OAuthRedirectHandler] Failed to get initial deep link: $e');
      }
    }

    // 2. Warm State Listener: App already running when OAuth redirect arrives
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        if (kDebugMode) {
          print('📱 [OAuthRedirectHandler] Incoming warm link detected: $uri');
        }
        await _processUri(uri);
      },
      onError: (err) {
        if (kDebugMode) {
          print('❌ [OAuthRedirectHandler] Deep link stream error: $err');
        }
      },
    );

    if (kDebugMode) {
      print('✅ [OAuthRedirectHandler] Deep link & OAuth callback infrastructure initialized');
    }
  }

  /// Processes and parses incoming deep link URLs (`clerk://oauth_callback` or custom schemes)
  Future<void> _processUri(Uri uri) async {
    final uriString = uri.toString();
    if (_lastProcessedUri == uriString) {
      if (kDebugMode) {
        print('ℹ️ [OAuthRedirectHandler] Skipping duplicate link processing: $uriString');
      }
      return;
    }
    _lastProcessedUri = uriString;

    // Verify if this is a Clerk OAuth Callback
    // Supported schemes:
    // - clerk://oauth_callback?...
    // - https://ur-heart.com/oauth_callback?...
    final isClerkScheme = uri.scheme == 'clerk' && (uri.host == 'oauth_callback' || uri.path.contains('oauth_callback'));
    final isHttpCallback = uri.path.contains('oauth_callback') || uri.path.contains('sso-callback');

    if (!isClerkScheme && !isHttpCallback) {
      if (kDebugMode) {
        print('ℹ️ [OAuthRedirectHandler] Non-OAuth URI received: $uri');
      }
      return;
    }

    final queryParams = uri.queryParameters;
    final error = queryParams['error'] ?? queryParams['error_code'];
    final errorDescription = queryParams['error_description'] ?? queryParams['error_message'];

    if (error != null && error.isNotEmpty) {
      final event = OAuthCallbackEvent(
        rawUri: uri,
        isSuccess: false,
        error: error,
        errorDescription: errorDescription,
      );
      _callbackController.add(event);
      return;
    }

    // Extract authorization code / session token / state
    final code = queryParams['code'] ?? queryParams['token'];
    final sessionToken = queryParams['session_token'] ?? queryParams['__clerk_session_token'] ?? queryParams['jwt'];
    final createdSessionId = queryParams['created_session_id'] ?? queryParams['session_id'];
    final state = queryParams['state'];

    if (sessionToken != null && sessionToken.isNotEmpty) {
      // Save session token in secure storage for automatic Dio interceptor injection
      await StorageManager.instance.saveAuthToken(sessionToken);
      
      // Auto-sync with FastAPI backend
      try {
        await UserRepository().syncClerkUserSession();
      } catch (syncErr) {
        if (kDebugMode) {
          print('⚠️ [OAuthRedirectHandler] Auto-sync warning on OAuth callback: $syncErr');
        }
      }
    }

    final event = OAuthCallbackEvent(
      rawUri: uri,
      isSuccess: true,
      code: code,
      sessionToken: sessionToken,
      createdSessionId: createdSessionId,
      state: state,
    );

    if (kDebugMode) {
      print('🎉 [OAuthRedirectHandler] Successfully handled OAuth callback: ${event.toString()}');
    }

    _callbackController.add(event);
  }

  /// Manually dispose stream subscriptions when no longer needed
  void dispose() {
    _linkSubscription?.cancel();
    _callbackController.close();
  }
}
