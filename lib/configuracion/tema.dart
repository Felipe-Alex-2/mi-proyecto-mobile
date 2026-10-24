import 'package:flutter/material.dart';

class TemaApp {
  // VESTA editorial palette for the mobile storefront.
  static const terracotta = Color(0xFFA34F3D);
  static const terracottaLight = Color(0xFFC5907E);
  static const brown = Color(0xFF2C211D);
  static const brownMedium = Color(0xFF756B65);
  static const cream = Color(0xFFF2EDE6);
  static const creamLight = Color(0xFFFAF7F2);
  static const sage = Color(0xFFDCE5DB);
  static const sageInk = Color(0xFF3F5946);
  static const border = Color(0xFFE9E1D9);
  static const editorial = TextStyle(
    fontFamily: 'VestaEditorial',
    fontSize: 32,
    height: 1.08,
    fontWeight: FontWeight.w500,
    color: brown,
  );
  static const surface = Color(0xFFFFFFFF);
  static const errorColor = Color(0xFFDC2626);
  static const successColor = Color(0xFF16A34A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'VestaBody',
      brightness: Brightness.light,
      scaffoldBackgroundColor: creamLight,
      primaryColor: terracotta,
      textTheme: Typography.material2021().black.apply(
        fontFamily: 'VestaBody',
        bodyColor: brown,
        displayColor: brown,
      ),
      colorScheme: const ColorScheme.light(
        primary: terracotta,
        secondary: sageInk,
        secondaryContainer: sage,
        onSecondaryContainer: sageInk,
        surface: surface,
        error: errorColor,
        onPrimary: Colors.white,
        onSurface: brown,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: creamLight,
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
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: errorColor, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2.5),
        ),
        errorStyle: const TextStyle(
          color: errorColor,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
        labelStyle: const TextStyle(color: brownMedium),
        hintStyle: TextStyle(color: brownMedium.withValues(alpha: 0.6)),
        prefixIconColor: brownMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brown,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
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
            fontFamily: 'VestaBody',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: terracotta),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamLight,
        selectedColor: terracotta,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(fontFamily: 'VestaBody', fontSize: 13),
        side: BorderSide(color: terracotta.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: terracotta.withValues(alpha: 0.1),
      iconTheme: const IconThemeData(color: brownMedium),
    );
  }
}
