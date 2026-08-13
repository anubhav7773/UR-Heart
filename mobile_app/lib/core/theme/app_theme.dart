import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette
  static const Color primaryColor = Color(0xFFE91E63); // Vibrant Rose Crimson
  static const Color primaryDarkColor = Color(0xFFC2185B);
  static const Color secondaryColor = Color(0xFFFFB300); // Warm Gold / Chai Accent
  static const Color backgroundColor = Color(0xFF121212); // Deep Charcoal Slate
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF262626);
  static const Color accentColor = Color(0xFFFF4081);

  // Chat Bubble Aesthetics
  static const LinearGradient sentBubbleGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color receivedBubbleColor = Color(0xFF2C2C2E);

  // Material 3 Dark Theme Definition
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
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
    );
  }
}
