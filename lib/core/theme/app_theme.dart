import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF185FC9);
  static const Color primaryContainer = Color(0xFFEAF3FF);
  static const Color secondary = Color(0xFF09AFDC);
  static const Color secondaryContainer = Color(0xFFE6F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDF3FA);
  static const Color background = Color(0xFFF4F8FE);
  static const Color textPrimary = Color(0xFF102F5C);
  static const Color textSecondary = Color(0xFF52647C);
  static const Color outline = Color(0xFFD5E2F0);
  static const Color onBrand = Color(0xFFFFFFFF);
  static const Color onBrandMuted = Color(0xFFD2E5F8);
  static const Color errorSurface = Color(0xFFFFEDF1);
  static const Color shadow = Color(0x0B185FC9);
  static const Color brandBlue = primary;
  static const Color navy = textPrimary;
  static const Color cyan = secondary;
  static const Color paleBlue = primaryContainer;
  static const Color borderBlue = outline;
  static const Color canvas = background;
  // Compatibilidad de los componentes V0.1 con la nueva identidad visual.
  static const Color primaryGreen = brandBlue;
  static const Color darkGreen = navy;
  static const Color softGreen = paleBlue;
  static const Color mintBackground = canvas;
  static const Color pureWhite = surface;
  static const Color error = Color(0xFFCC4058);
  static const Color expenseRed = error;
  static const Color softRed = Color(0xFFFFEDF1);
  static const Color textDark = navy;
  static const Color textMuted = textSecondary;
  static const Color success = Color(0xFF087F71);
  static const Color warning = Color(0xFF865800);
  static const Color warningSurface = Color(0xFFFFF6DF);

  static ThemeData get lightTheme {
    final colors = ColorScheme.fromSeed(
        seedColor: brandBlue,
        primary: brandBlue,
        secondary: cyan,
        primaryContainer: paleBlue,
        secondaryContainer: secondaryContainer,
        surface: pureWhite,
        onSurface: navy,
        error: expenseRed,
        surfaceContainerLow: canvas,
        surfaceContainer: pureWhite,
        surfaceContainerHigh: surfaceVariant,
        surfaceContainerHighest: primaryContainer,
        outline: outline,
        outlineVariant: outline,
        brightness: Brightness.light);
    final base = ThemeData(
        useMaterial3: true, colorScheme: colors, fontFamily: 'Roboto');
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: base.textTheme
          .apply(bodyColor: navy, displayColor: navy)
          .copyWith(
            headlineMedium: const TextStyle(
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
                color: navy),
            headlineSmall: const TextStyle(
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
                color: navy),
            titleLarge: const TextStyle(
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: navy),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: navy),
          )
          .apply(fontFamily: 'Roboto'),
      appBarTheme: const AppBarTheme(
          backgroundColor: pureWhite,
          foregroundColor: navy,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: paleBlue,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: pureWhite,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: borderBlue))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(color: textMuted),
        floatingLabelStyle:
            const TextStyle(color: brandBlue, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderBlue)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderBlue)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandBlue, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: shape,
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: shape,
              side: const BorderSide(color: borderBlue),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto', fontWeight: FontWeight.w600))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto', fontWeight: FontWeight.w600))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: pureWhite,
          indicatorColor: paleBlue,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy))),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? paleBlue : pureWhite),
              foregroundColor: WidgetStateProperty.all(navy),
              side: WidgetStateProperty.all(
                  const BorderSide(color: borderBlue)))),
      dividerTheme: const DividerThemeData(color: borderBlue, space: 28),
      iconTheme: const IconThemeData(color: brandBlue),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      popupMenuTheme: PopupMenuThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          behavior: SnackBarBehavior.floating,
          shape: shape),
    );
  }
}
