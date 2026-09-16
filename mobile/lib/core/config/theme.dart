import 'package:flutter/material.dart';

/// UR-Heart Dark Romantic Design System Tokens
/// Defined per URH-UIX-009 specification for Tier-2/Tier-3 audiences.
class URHeartColors {
  URHeartColors._();

  // Primary Palette
  static const Color canvasBackground = Color(0xFF0A0A0D); // Deep Obsidian Canvas
  static const Color cardSurface = Color(0xFF16161D); // Level 1 Surface, Card stacks, sheets
  static const Color surfaceRaised = Color(0xFF22222C); // Level 2 Surface, Input docks, chips
  static const Color brandPrimary = Color(0xFFFF2E63); // Electric Crimson, Like action, active heart
  static const Color brandSecondary = Color(0xFF08D9D6); // Cyber Turquoise, Direct DM, verified badges
  static const Color accentGold = Color(0xFFFFD166); // Flame Streaks, Ad Reward Tokens, Badges
  static const Color statusDanger = Color(0xFFFF334B); // Anti-Leak Red Banner, Report/Block actions
  static const Color statusSuccess = Color(0xFF06D6A0); // WhatsApp unlock status, KYC approved
  static const Color textPrimary = Color(0xFFFFFFFF); // High contrast text
  static const Color textSecondary = Color(0xFFA0A0B2); // Explanatory subtext
  static const Color textMuted = Color(0xFF636375); // Timestamps and inactive states
}

/// UR-Heart Theme Extensions & Global ThemeData
class URHeartTheme {
  URHeartTheme._();

  // Radii
  static const BorderRadius radiusCard = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusCardLarge = BorderRadius.all(Radius.circular(28));
  static const BorderRadius radiusModal = BorderRadius.vertical(top: Radius.circular(28));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(999));
  static const BorderRadius radiusInput = BorderRadius.all(Radius.circular(16));

  // Minimum Tap Target Size for Accessibility (WCAG 2.1 AA)
  static const double minTouchTarget = 48.0;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: URHeartColors.canvasBackground,
      colorScheme: const ColorScheme.dark(
        surface: URHeartColors.cardSurface,
        primary: URHeartColors.brandPrimary,
        secondary: URHeartColors.brandSecondary,
        error: URHeartColors.statusDanger,
        onSurface: URHeartColors.textPrimary,
        onPrimary: URHeartColors.textPrimary,
        onSecondary: URHeartColors.canvasBackground,
      ),
      cardTheme: const CardThemeData(
        color: URHeartColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusCard),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: URHeartColors.canvasBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: URHeartColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: URHeartColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: URHeartColors.brandPrimary,
          foregroundColor: URHeartColors.textPrimary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: radiusPill),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: URHeartColors.textPrimary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: radiusPill),
          side: const BorderSide(color: URHeartColors.surfaceRaised, width: 1.5),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: URHeartColors.surfaceRaised,
        hintStyle: TextStyle(color: URHeartColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: radiusInput,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusInput,
          borderSide: BorderSide(color: URHeartColors.brandSecondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusInput,
          borderSide: BorderSide(color: URHeartColors.statusDanger, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: URHeartColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: radiusModal),
      ),
    );
  }
}
