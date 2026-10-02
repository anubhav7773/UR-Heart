import 'dart:js_interop';

@JS('setUrHeartPrivacyMode')
external void _setUrHeartPrivacyMode(bool enabled);

@JS('showWebNotification')
external void _showWebNotification(JSString title, JSString body);

@JS('requestWebNotificationPermission')
external JSPromise<JSString> _requestWebNotificationPermission();

/// Enforces web screenshot and screen capture obfuscation in 1:1 Encrypted Dialogues
void setWebPrivacyMode(bool enabled) {
  try {
    _setUrHeartPrivacyMode(enabled);
  } catch (_) {}
}

/// Dispatches native HTML5 browser notification
void showBrowserNotification(String title, String body) {
  try {
    _showWebNotification(title.toJS, body.toJS);
  } catch (_) {}
}

/// Prompts user for browser notification permission
Future<String> requestBrowserNotificationPermission() async {
  try {
    final jsPromise = _requestWebNotificationPermission();
    final result = await jsPromise.toDart;
    return result.toDart;
  } catch (_) {
    return 'denied';
  }
}
