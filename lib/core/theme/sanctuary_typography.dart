import 'package:flutter/material.dart';

/// UR-Heart Sanctuary Typography Tokens
/// Editorial Serif: Playfair Display for poetic titles & headings
/// Clean Sans: Plus Jakarta Sans for body, controls & legal notices
class SanctuaryTypography {
  const SanctuaryTypography._();

  static const String serifFontFamily = 'PlayfairDisplay';
  static const String sansFontFamily = 'PlusJakartaSans';

  // Editorial Serif Headers
  static const TextStyle titleH1 = TextStyle(
    fontFamily: serifFontFamily,
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const TextStyle titleH1Italic = TextStyle(
    fontFamily: serifFontFamily,
    fontSize: 32.0,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.3,
    height: 1.15,
  );

  static const TextStyle titleH2 = TextStyle(
    fontFamily: serifFontFamily,
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.20,
  );

  static const TextStyle quote = TextStyle(
    fontFamily: serifFontFamily,
    fontSize: 18.0,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.2,
    height: 1.35,
  );

  // Clean Sans-Serif Body & UI
  static const TextStyle bodyStandard = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );

  static const TextStyle accordionCategory = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}
