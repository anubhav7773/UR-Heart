import 'dart:js_interop';

@JS('setUrHeartPrivacyMode')
external void _setUrHeartPrivacyMode(bool enabled);

@JS('dismissSanctuarySplash')
external void _dismissSanctuarySplash();

/// Enforces web screenshot and screen capture obfuscation in 1:1 Encrypted Dialogues
void setWebPrivacyMode(bool enabled) {
  try {
    _setUrHeartPrivacyMode(enabled);
  } catch (_) {}
}

/// Seamlessly fades out the startup HTML splash screen on first Flutter frame
void dismissWebSplash() {
  try {
    _dismissSanctuarySplash();
  } catch (_) {}
}
