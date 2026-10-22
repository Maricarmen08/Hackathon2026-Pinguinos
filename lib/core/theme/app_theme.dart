import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkGreen = Color(0xFF047857);
  static const Color softGreen = Color(0xFFD1FAE5);
  static const Color mintBackground = Color(0xFFF4FBF7);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color expenseRed = Color(0xFFEF4444);
  static const Color softRed = Color(0xFFFEE2E2);
  static const Color textDark = Color(0xFF064E3B);
  static const Color textMuted = Color(0xFF6B7280);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: mintBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: darkGreen,
        surface: pureWhite,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: softGreen, width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pureWhite,
        indicatorColor: softGreen,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
      ),
    );
  }
}

