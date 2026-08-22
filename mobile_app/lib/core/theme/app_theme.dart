// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

class AppTheme {
  // 1. Design System & Global Token Hierarchy (Section 1.1)
  // Background & Surfaces
  static const Color surface_root = Color(0xFF0A0B10);
  static const Color surfaceRoot = surface_root;

  static const Color surface_card = Color(0xFF14161F);
  static const Color surfaceCard = surface_card;

  static const Color surface_interactive = Color(0xFF1C1F2E);
  static const Color surfaceInteractive = surface_interactive;

  static const Color border_subtle = Color(0xFF272A3D);
  static const Color borderSubtle = border_subtle;

  // Brand Accents & Trust Vectors
  static const Color accent_primary = Color(0xFFFF3366);
  static const Color accentPrimary = accent_primary;

  static const Color accent_boost_gold = Color(0xFFFFB800);
  static const Color accentBoostGold = accent_boost_gold;

  static const Color accent_verified_blue = Color(0xFF00B4D8);
  static const Color accentVerifiedBlue = accent_verified_blue;

  static const Color status_online = Color(0xFF00E676);
  static const Color statusOnline = status_online;

  static const Color status_destructive = Color(0xFFFF4D4D);
  static const Color statusDestructive = status_destructive;

  // Typography Hierarchy
  static const Color text_primary = Color(0xFFFFFFFF);
  static const Color textPrimary = text_primary;

  static const Color text_secondary = Color(0xFF8E92A8);
  static const Color textSecondary = text_secondary;

  static const Color text_tertiary = Color(0xFF5E6278);
  static const Color textTertiary = text_tertiary;

  // 1.2 Layout & Elevation Standards
  static const double radius_sm = 8.0;
  static const double radiusSm = radius_sm;

  static const double radius_md = 14.0;
  static const double radiusMd = radius_md;

  static const double radius_lg = 20.0;
  static const double radiusLg = radius_lg;

  // Legacy & Compatibility Aliases
  static const Color backgroundColor = surfaceRoot;
  static const Color surfaceColor = surfaceCard;
  static const Color cardColor = surfaceCard;
  static const Color cardBorderColor = borderSubtle;
  static const Color borderColor = borderSubtle;

  static const Color primaryColor = accentPrimary;
  static const Color primaryDarkColor = Color(0xFFE02856);
  static const Color accentColor = accentPrimary;

  static const Color verifiedBlue = accentVerifiedBlue;
  static const Color secondaryColor = accentBoostGold;

  static const Color textPrimaryColor = textPrimary;
  static const Color textSecondaryColor = textSecondary;
  static const Color mutedTextColor = textSecondary;

  // 2. Chat Bubble Aesthetics
  static const LinearGradient sentBubbleGradient = LinearGradient(
    colors: [Color(0xFFFF3366), Color(0xFFE02856)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color receivedBubbleColor = Color(0xFF1C1F2E);
  static const Color receivedBubbleBorderColor = borderSubtle;

  // 3. Common Card & Container Decorations
  static BoxDecoration get cardBoxDecoration => BoxDecoration(
    color: surfaceCard,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: borderSubtle, width: 1),
  );

  static BoxDecoration cardBoxDecorationWithRadius(double radius) => BoxDecoration(
    color: surfaceCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderSubtle, width: 1),
  );

  // 4. Material 3 Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surfaceRoot,
      primaryColor: accentPrimary,
      colorScheme: const ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentBoostGold,
        surface: surfaceCard,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceRoot,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderSubtle, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceInteractive,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
      ),
    );
  }
}
