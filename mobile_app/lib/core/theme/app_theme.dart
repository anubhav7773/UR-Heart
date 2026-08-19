import 'package:flutter/material.dart';

class AppTheme {
  // 1. Standardized Modern Color Palette
  static const Color backgroundColor = Color(0xFF0D0E15); // Deep Obsidian
  static const Color surfaceColor = Color(0xFF171822);    // Dark Surface
  static const Color cardColor = Color(0xFF171822);       // Card Background
  static const Color cardBorderColor = Color(0xFF252736); // Subtle 1px Border
  static const Color borderColor = Color(0xFF252736);

  static const Color primaryColor = Color(0xFFFF3366);     // Coral Pink
  static const Color primaryDarkColor = Color(0xFFE02856);
  static const Color accentColor = Color(0xFFFF3366);

  static const Color verifiedBlue = Color(0xFF34B7F1);     // Electric Blue (Verified & Read Ticks)
  static const Color secondaryColor = Color(0xFFFFB300);   // Warm Gold (Super Boost & VIP)

  static const Color textPrimaryColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF8E92A4);
  static const Color mutedTextColor = Color(0xFF8E92A4);

  // 2. Chat Bubble Aesthetics
  static const LinearGradient sentBubbleGradient = LinearGradient(
    colors: [Color(0xFFFF3366), Color(0xFFE02856)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color receivedBubbleColor = Color(0xFF1F212D);
  static const Color receivedBubbleBorderColor = Color(0xFF252736);

  // 3. Common Card & Container Decorations
  static BoxDecoration get cardBoxDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: cardBorderColor, width: 1),
  );

  static BoxDecoration cardBoxDecorationWithRadius(double radius) => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: cardBorderColor, width: 1),
  );

  // 4. Material 3 Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: cardBorderColor, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: mutedTextColor, fontSize: 14),
      ),
    );
  }
}
