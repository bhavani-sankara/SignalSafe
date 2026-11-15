import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignalPalette {
  const SignalPalette({
    required this.ink,
    required this.surface,
    required this.elevated,
    required this.text,
    required this.muted,
    required this.beacon,
    required this.route,
    required this.good,
    required this.moderate,
    required this.weak,
    required this.none,
    required this.sos,
    required this.border,
    required this.glass,
  });

  final Color ink;
  final Color surface;
  final Color elevated;
  final Color text;
  final Color muted;
  final Color beacon;
  final Color route;
  final Color good;
  final Color moderate;
  final Color weak;
  final Color none;
  final Color sos;
  final Color border;
  final Color glass;

  static const dark = SignalPalette(
    ink: Color(0xFF0B1118),
    surface: Color(0xFF151C26),
    elevated: Color(0xFF1C2633),
    text: Color(0xFFE7EEF6),
    muted: Color(0xFF8B9AAB),
    beacon: Color(0xFF2FD3C5),
    route: Color(0xFF6BA8FF),
    good: Color(0xFF2FD3C5),
    moderate: Color(0xFFE0B04A),
    weak: Color(0xFFE07A3A),
    none: Color(0xFF4A5563),
    sos: Color(0xFFE11D2E),
    border: Color(0xFF2A3544),
    glass: Color(0xE6151C26),
  );

  static const light = SignalPalette(
    ink: Color(0xFFF3F6FA),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFEEF3F8),
    text: Color(0xFF12202E),
    muted: Color(0xFF5B6B7C),
    beacon: Color(0xFF128F86),
    route: Color(0xFF2F6FDB),
    good: Color(0xFF128F86),
    moderate: Color(0xFFB8860B),
    weak: Color(0xFFC45C1A),
    none: Color(0xFF6B7280),
    sos: Color(0xFFD50F22),
    border: Color(0xFFD5DEE8),
    glass: Color(0xF2FFFFFF),
  );

  Color level(String level) => switch (level) {
        'good' => good,
        'moderate' => moderate,
        'weak' => weak,
        _ => none,
      };
}

class AppTheme {
  static ThemeData of(Brightness brightness) {
    final pal = brightness == Brightness.dark
        ? SignalPalette.dark
        : SignalPalette.light;
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    // google_fonts 9 returns material_ui text styles, which are a
    // different type from Flutter's TextTheme. Apply the family name only.
    final outfitFamily = GoogleFonts.outfit().fontFamily;
    return base.copyWith(
      scaffoldBackgroundColor: pal.ink,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: pal.beacon,
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF06201C)
            : Colors.white,
        secondary: pal.route,
        onSecondary: Colors.white,
        error: pal.sos,
        onError: Colors.white,
        surface: pal.surface,
        onSurface: pal.text,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: outfitFamily,
        bodyColor: pal.text,
        displayColor: pal.text,
      ),
      splashFactory: InkRipple.splashFactory,
      dividerColor: pal.border,
      appBarTheme: AppBarTheme(
        backgroundColor: pal.ink,
        foregroundColor: pal.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: outfitFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: pal.text,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.surface,
        modalBackgroundColor: pal.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: pal.beacon, width: 1.4),
        ),
        hintStyle: TextStyle(color: pal.muted),
      ),
    );
  }
}

extension PaletteContext on BuildContext {
  SignalPalette get palette {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return dark ? SignalPalette.dark : SignalPalette.light;
  }
}

TextStyle dataStyle(BuildContext context, {double size = 14, FontWeight? weight}) {
  return TextStyle(
    fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w500,
    color: context.palette.text,
  );
}
