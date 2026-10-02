import 'dart:js_interop';

@JS('setUrHeartPrivacyMode')
external void _setUrHeartPrivacyMode(bool enabled);

/// Enforces web screenshot and screen capture obfuscation in 1:1 Encrypted Dialogues
void setWebPrivacyMode(bool enabled) {
  try {
    _setUrHeartPrivacyMode(enabled);
  } catch (_) {}
}
