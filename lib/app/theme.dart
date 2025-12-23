import 'package:flutter/material.dart';

class AppTheme {
  // Palette
  static const Color darkGray = Color(0xFF1F1F1F);
  static const Color gray900 = Color(0xFF121212);
  static const Color gray800 = Color(0xFF2A2A2A);
  static const Color gray100 = Color(0xFFF3F3F3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gold = Color(
    0xFFFFC107,
  ); // golden yellow with good contrast
  static const Color goldDeep = Color(0xFFE0A800);

  static ThemeData theme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        primary: gold,
        onPrimary: gray900,
        background: gray900,
        surface: gray800,
        onSurface: white,
      ),
      scaffoldBackgroundColor: gray900,
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: gray900,
        foregroundColor: white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: gray800,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gray800,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: gray900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
    );
  }
}
