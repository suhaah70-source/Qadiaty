import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0D330E);
  static const inkLight = Color(0xFF2D531A);
  static const darkGreen = Color(0xFF071E07);
  static const burgundy = Color(0xFF477023);
  static const navyBlue = Color(0xFF2D531A);
  static const dustyBlue = Color(0xFF6E8649);
  static const warmBeige = Color(0xFFE7EBDD);
  static const primaryBlue = Color(0xFF477023);
  static const royalBlue = Color(0xFF314B68);
  static const cobaltBlue = Color(0xFF496783);
  static const sapphireBlue = Color(0xFF627C98);
  static const tealBlue = Color(0xFF476E7D);
  static const ceruleanBlue = dustyBlue;
  static const skyBlue = Color(0xFFB4C1D0);
  static const powderBlue = Color(0xFFE9EEF3);
  static const iceBlue = Color(0xFFF3F5EF);
  static const canvas = iceBlue;
  static const paper = Color(0xFFFFFCF6);
  static const brass = Color(0xFF6E8649);
  static const brassLight = Color(0xFF2D531A);
  static const jade = Color(0xFF477023);
  static const rust = Color(0xFFB3261E);
  static const ash = Color(0xFF66758A);
  static const ashLight = warmBeige;
}

/// إعداد مظهر التطبيق باستخدام Material 3 وألوان وهوية سوقي.
ThemeData buildMercatoTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF0D330E) : AppColors.paper;
  final canvas = dark ? const Color(0xFF071E07) : AppColors.canvas;
  final foreground = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: brightness,
      primary: dark ? const Color(0xFF6E8649) : AppColors.ink,
      secondary: dark ? const Color(0xFF6E8649) : AppColors.burgundy,
      surface: surface,
    ).copyWith(
      onSurface: foreground,
      onSurfaceVariant:
          dark ? const Color(0xFFD1D5DB) : const Color(0xFF000000),
    ),
    scaffoldBackgroundColor: canvas,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? surface : AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: dark ? const Color(0xFF303640) : AppColors.ashLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: dark ? const Color(0xFF3A414C) : AppColors.ashLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    ),
    textTheme: ThemeData(brightness: brightness)
        .textTheme
        .apply(bodyColor: foreground, displayColor: foreground),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.canvas,
      selectedColor: AppColors.burgundy,
      labelStyle: const TextStyle(fontSize: 12.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: dark ? const Color(0xFF6E8649) : AppColors.primaryBlue,
      unselectedItemColor: dark ? const Color(0xFFBEC6D1) : AppColors.ash,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}

/// تدرج لوني موحد يُستخدم في عناصر الهوية والشاشة الافتتاحية.
const kInkGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.ink, AppColors.inkLight],
);

/// نمط كتابة موحد لاسم التطبيق والعناوين البارزة.
TextStyle kWordmarkStyle({double fontSize = 24, Color color = Colors.white}) {
  return TextStyle(
    fontFamily: 'Roboto',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 0.15,
  );
}
