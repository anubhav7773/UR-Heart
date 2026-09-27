/// Result of client-side NLP chat sanitization inspection
class SanitizationResult {
  final bool isValid;
  final String? violationCode;
  final String? userFriendlyMessage;

  const SanitizationResult({
    required this.isValid,
    this.violationCode,
    this.userFriendlyMessage,
  });

  static const SanitizationResult clean = SanitizationResult(isValid: true);
}

/// Client-side NLP Chat Sanitizer Gatekeeper for UR-Heart
/// Blocks off-platform contact sharing before dispatch per Doc 08.
class NlpChatSanitizer {
  const NlpChatSanitizer._();

  static final RegExp _indianPhoneRegex = RegExp(
    r'(?:(?:\+?91|091|91|0)[\s\.\-/]*)?([6-9](?:[\s\.\-/]*\d){9})',
    caseSensitive: false,
  );

  static final RegExp _raw10DigitRegex = RegExp(r'[6-9]\d{9}');

  static const Map<String, String> _numberWordsMap = {
    // English
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    // Hindi transliteration
    'shunya': '0', 'sunya': '0', 'ek': '1', 'ik': '1', 'do': '2', 'doo': '2',
    'teen': '3', 'tin': '3', 'chaar': '4', 'char': '4', 'paanch': '5',
    'panch': '5', 'pach': '5', 'chhe': '6', 'chheh': '6', 'che': '6',
    'saat': '7', 'sat': '7', 'aath': '8', 'aat': '8', 'ath': '8',
    'nau': '9', 'no': '9', 'now': '9',
  };

  static final RegExp _numberWordsRegex = RegExp(
    r'\b(' + _numberWordsMap.keys.join('|') + r')\b',
    caseSensitive: false,
  );

  static final RegExp _socialKeywordsRegex = RegExp(
    r'(?:whatsapp|watsapp|watsap|vatsap|whatapp|instagram|instagr|telegram|snapchat|'
    r'facebook|twitter|linkedin|discord|tiktok|threads|signal|paytm|gpay|phonepe|bhim)',
    caseSensitive: false,
  );

  static final RegExp _shortSocialHandleRegex = RegExp(
    r'(?:^|[\s,;])(?:@|ig|i_g|i-g|wa|w-a|w/a|tele|tg|sc|snap|fb)[\s:_\-]*[a-zA-Z0-9_.]{3,30}',
    caseSensitive: false,
  );

  static final RegExp _urlAndEmailRegex = RegExp(
    r'(?:https?://\S+|www\.\S+|\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b|'
    r'\b(?:wa\.me|t\.me|ig\.me|snapchat\.com|bit\.ly)/\S+)',
    caseSensitive: false,
  );

  static final RegExp _upiVpaRegex = RegExp(
    r'\b[a-zA-Z0-9.\-_]{2,256}@(okhdfcbank|okaxis|okicici|oksbi|paytm|ybl|ibl|upi)\b',
    caseSensitive: false,
  );

  /// Inspects a message for contact leakage or off-platform communication evasion
  static SanitizationResult inspect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return SanitizationResult.clean;

    // Normalization & de-obfuscation
    final normalized = _cleanInvisibleChars(trimmed.toLowerCase());
    final condensed = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Direct Indian phone numbers
    if (_indianPhoneRegex.hasMatch(normalized) || _raw10DigitRegex.hasMatch(digitsOnly)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'PHONE_NUMBER_DETECTED',
        userFriendlyMessage:
            'Sharing phone numbers is strictly shielded. Use the 3-ad Enclave Reveal Ritual on Screen 10 to connect off-platform.',
      );
    }

    // 2. Transliterated phone numbers (Hindi & English written words)
    final convertedDigits = _convertNumberWords(normalized);
    if (_raw10DigitRegex.hasMatch(convertedDigits)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'TRANSLITERATED_PHONE_NUMBER_DETECTED',
        userFriendlyMessage:
            'Written phone numbers are blocked. UR-Heart protects both users through the Enclave Reveal Ritual.',
      );
    }

    // 3. UPI Virtual Payment Addresses (VPA) checked before URLs / generic handles
    if (_upiVpaRegex.hasMatch(normalized)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'UPI_PAYMENT_HANDLE_DETECTED',
        userFriendlyMessage:
            'Financial handles and UPI addresses are strictly prohibited inside the dialogue sanctuary.',
      );
    }

    // 4. External links, web domains & emails
    if (_urlAndEmailRegex.hasMatch(normalized)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'EXTERNAL_LINK_OR_EMAIL_DETECTED',
        userFriendlyMessage:
            'External links and emails cannot be shared in dialogues for user safety under DPDP Act 2023.',
      );
    }

    // 5. Social platform names (e.g., WhatsApp, Instagram, Telegram)
    if (_socialKeywordsRegex.hasMatch(condensed)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'SOCIAL_PLATFORM_KEYWORD_DETECTED',
        userFriendlyMessage:
            'Direct social platform references are blocked. Conversations stay in the sanctuary until mutual reveal.',
      );
    }

    // 6. Short handles & prefixes (@user, ig:user, wa:...)
    if (_shortSocialHandleRegex.hasMatch(normalized)) {
      return const SanitizationResult(
        isValid: false,
        violationCode: 'SOCIAL_HANDLE_PREFIX_DETECTED',
        userFriendlyMessage:
            'Social handles and external tags are restricted to preserve mindful dating intentionality.',
      );
    }

    return SanitizationResult.clean;
  }

  static String _cleanInvisibleChars(String input) {
    const invisibleChars = ['\u200b', '\u200c', '\u200d', '\ufeff', '\u200e', '\u200f', '\u00a0'];
    String result = input;
    for (final char in invisibleChars) {
      result = result.replaceAll(char, '');
    }
    return result;
  }

  static String _convertNumberWords(String text) {
    final replaced = text.replaceAllMapped(_numberWordsRegex, (match) {
      final word = match.group(0)?.toLowerCase();
      if (word == null) return '';
      return _numberWordsMap[word] ?? word;
    });
    return replaced.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
