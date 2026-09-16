/// Bilingual (English & Hindi) Vernacular Localization Dictionary
/// Conforming to Section 4 of URH-UIX-009 for Tier-2/Tier-3 audiences.
class VernacularStrings {
  VernacularStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'btnGoogleAuth': 'Continue with Google',
      'btnPhoneAuth': 'Use Phone Number / मोबाइल नंबर से लॉगिन',
      'ageGateNotice': 'Strictly 18+ years only',
      'ageGateSubtext': 'Neutral date of birth selection required',
      'feedAdCounter': 'Ad in {x} swipes',
      'directDmCta': 'Watch 10s Ad -> 3 Direct DMs',
      'screenshotBlocked': '🔒 Protected by FLAG_SECURE',
      'antiLeakError': 'Sharing phone numbers, social handles (@, IG, WA, Snap) is prohibited.',
      'antiLeakTitle': '🚫 Contact Sharing Blocked',
      'antiLeakNotice': 'Photos with numbers, Instagram handles (@, IG), WhatsApp, or QR codes are rejected by AI.',
      'waRevealButton': 'Unlock WhatsApp 💬',
      'waRevealTitle': 'Unlock Mutual WhatsApp Contact',
      'waRevealProgress': 'Both you and match must watch 3 video clips to reveal numbers.',
      'waRevealDisclaimer': 'Contact is revealed only when both reach 3/3. 100% free forever.',
      'streakTitle': 'Active Fire Streak',
      'uninstallWarning': 'Uninstalling or clearing app data resets your streak and rewards to 0.',
      'dataEraseButton': 'Delete Account & Erase All Data',
      'dataEraseNotice': 'Instantly deletes all photos, messages, and KYC files per DPDP Act 2023.',
      'verifyContinue': 'Verify & Continue',
      'fiveSecVideoTitle': '5-Second Safety Video',
      'fiveSecVideoSub': 'Say your name and city to confirm identity. Deleted in 24 hours.',
      'recordVideoAction': 'Start Quick Recording (5s)',
      'stepTwoOfThree': 'Step 2 of 3',
      'profileHero': 'Main Display Picture (Profile Hero)',
      'ocrVerifiedTag': 'AI OCR Verified',
      'directDmsBalance': 'Direct DMs Available',
      'totalAdsSupported': 'Total Ads Supported',
      'legalFooter': 'By joining UR-Heart, you agree to EULA Terms, DPDP Privacy Notice, and Zero-Harassment Policy. Operated by ASI Verticals.',
    },
    'hi': {
      'btnGoogleAuth': 'गूगल से आगे बढ़ें',
      'btnPhoneAuth': 'मोबाइल नंबर से लॉगिन करें',
      'ageGateNotice': 'केवल 18+ वर्ष के लिए',
      'ageGateSubtext': 'अपनी वास्तविक जन्मतिथि चुनें',
      'feedAdCounter': '{x} स्वाइप बाद विज्ञापन',
      'directDmCta': '10s विज्ञापन देखें -> 3 डायरेक्ट मैसेज',
      'screenshotBlocked': '🔒 स्क्रीनशॉट और रिकॉर्डिंग ब्लॉक है',
      'antiLeakError': 'फ़ोन नंबर या सोशल मीडिया आईडी (Instagram, WhatsApp) शेयर करना वर्जित है।',
      'antiLeakTitle': '🚫 संपर्क साझा करना वर्जित है',
      'antiLeakNotice': 'फ़ोन नंबर, इंस्टाग्राम आईडी, व्हाट्सएप या क्यूआर कोड वाली तस्वीरें एआई द्वारा अस्वीकार कर दी जाएंगी।',
      'waRevealButton': 'व्हाट्सएप अनलॉक करें 💬',
      'waRevealTitle': 'व्हाट्सएप नंबर अनलॉक करें',
      'waRevealProgress': 'नंबर देखने के लिए आप दोनों को 3 छोटे वीडियो विज्ञापन देखने होंगे।',
      'waRevealDisclaimer': 'दोनों के 3/3 पूरा करने पर ही नंबर दिखेगा। हमेशा 100% मुफ़्त।',
      'streakTitle': 'सक्रिय लपट स्ट्रीक',
      'uninstallWarning': 'ऐप हटाने या डेटा मिटाने पर आपकी स्ट्रीक और रिवॉर्ड 0 हो जाएंगे।',
      'dataEraseButton': 'खाता और डेटा हमेशा के लिए मिटाएं',
      'dataEraseNotice': 'डीपीडीपी अधिनियम 2023 के तहत सभी फ़ोटो, संदेश और डेटा तुरंत मिटा दिए जाएंगे।',
      'verifyContinue': 'सत्यापित करें और आगे बढ़ें',
      'fiveSecVideoTitle': '5-सेकंड की सेल्फ़ी वीडियो',
      'fiveSecVideoSub': 'पहचान की पुष्टि के लिए अपना नाम और शहर बोलें। 24 घंटे में हटा दिया जाएगा।',
      'recordVideoAction': 'त्वरित रिकॉर्डिंग शुरू करें (5s)',
      'stepTwoOfThree': 'चरण 2 / 3',
      'profileHero': 'मुख्य प्रोफ़ाइल फ़ोटो',
      'ocrVerifiedTag': 'एआई ओसीआर सत्यापित',
      'directDmsBalance': 'उपलब्ध डायरेक्ट संदेश',
      'totalAdsSupported': 'देखे गए प्रायोजित विज्ञापन',
      'legalFooter': 'UR-Heart से जुड़कर, आप EULA सेवा की शर्तों, DPDP गोपनीयता सूचना और उत्पीड़न विरोधी नीति से सहमत होते हैं। ASI Verticals द्वारा संचालित।',
    },
  };

  /// Translates [key] to given [lang] ('en' or 'hi') and dynamically replaces {arg} patterns.
  static String tr(String key, {String lang = 'en', Map<String, String>? args}) {
    final languageMap = _localizedValues[lang] ?? _localizedValues['en']!;
    String value = languageMap[key] ?? _localizedValues['en']![key] ?? key;

    if (args != null && args.isNotEmpty) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}
