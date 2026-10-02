import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ����� ������ �������� ����� "�������" — ��� ���� ������� �������� ��
/// ����� ������ ����� ���� ������ ���� ����� ����� ����� �����.
class AppColors {
  static const ink = Color(0xFF0D330E);
  static const inkLight = Color(0xFF2D531A);
  static const canvas = Color(0xFFF3F5EF);
  static const paper = Color(0xFFFFFFFF);
  static const brass = Color(0xFF6E8649);
  static const brassLight = Color(0xFF2D531A);
  static const jade = Color(0xFF477023);
  static const rust = Color(0xFFB54834);
  static const ash = Color(0xFF6B7280);
  static const ashLight = Color(0xFFDCE4D5);
}

ThemeData buildMercatoTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF0D330E) : AppColors.paper;
  final canvas = dark ? const Color(0xFF071E07) : AppColors.canvas;
  final foreground = dark ? Colors.white : Colors.black;
  final baseTextTheme =
      GoogleFonts.amiriTextTheme(ThemeData(brightness: brightness).textTheme)
          .apply(bodyColor: foreground, displayColor: foreground);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: brightness,
      primary: dark ? const Color(0xFF6E8649) : AppColors.ink,
      secondary: AppColors.brass,
      surface: surface,
    ).copyWith(
        onSurface: foreground,
        onSurfaceVariant: dark ? const Color(0xFFD0D6D1) : Colors.black),
    scaffoldBackgroundColor: canvas,
    textTheme: baseTextTheme,
    fontFamily: GoogleFonts.amiri().fontFamily,
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.ashLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.ashLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brass, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

const kInkGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.ink, AppColors.inkLight],
);

TextStyle kWordmarkStyle({double fontSize = 24, Color color = Colors.white}) {
  return GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.5);
}

/// ����� ������� �������� ������� (guilloché) ��������� ��� ������
/// �� ���� ������ ������� ������� ���� ��� ����� ������.
class HeritagePattern extends StatelessWidget {
  final double opacity;
  const HeritagePattern({super.key, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(painter: _HeritagePainter(), size: Size.infinite),
    );
  }
}

class _HeritagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    const step = 9.0;
    for (double d = -size.height; d < size.width; d += step) {
      canvas.drawLine(
          Offset(d, 0), Offset(d + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
