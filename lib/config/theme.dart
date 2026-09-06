import 'package:flutter/material.dart';

class AppTheme {
  // ── VESTA Warm Palette (synchronized with Angular web) ──
  static const terracotta = Color(0xFF8B4513);
  static const terracottaLight = Color(0xFFC4956A);
  static const brown = Color(0xFF2C1810);
  static const brownMedium = Color(0xFF8B7355);
  static const cream = Color(0xFFF5F0E8);
  static const creamLight = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const errorColor = Color(0xFFDC2626);
  static const successColor = Color(0xFF16A34A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: cream,
      primaryColor: terracotta,
      colorScheme: const ColorScheme.light(
        primary: terracotta,
        secondary: terracottaLight,
        surface: surface,
        error: errorColor,
        onPrimary: Colors.white,
        onSurface: brown,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: brown,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: terracotta.withValues(alpha: 0.12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: terracotta.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: terracotta.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terracotta, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: brownMedium),
        hintStyle: TextStyle(color: brownMedium.withValues(alpha: 0.6)),
        prefixIconColor: brownMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: terracotta,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamLight,
        selectedColor: terracotta,
        labelStyle: const TextStyle(fontSize: 13),
        side: BorderSide(color: terracotta.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerColor: terracotta.withValues(alpha: 0.1),
      iconTheme: const IconThemeData(color: brownMedium),
    );
  }
}
