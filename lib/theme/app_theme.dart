import 'package:flutter/material.dart';

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
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.outline,
    required this.destination,
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
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color outline;
  final Color destination;

  static const dark = SignalPalette(
    ink: Color(0xFF111917),
    surface: Color(0xFF151D1A),
    elevated: Color(0xFF1F2926),
    text: Color(0xFFE0E5E3),
    muted: Color(0xFFC0C9C6),
    beacon: Color(0xFF80D8CC),
    route: Color(0xFF80CBC4),
    good: Color(0xFFC9F0D5),
    moderate: Color(0xFFFFE7B3),
    weak: Color(0xFFFFD8A8),
    none: Color(0xFFBAC4C1),
    sos: Color(0xFFFFB4AB),
    border: Color(0xFF404947),
    glass: Color(0xFF1A2421),
    primaryContainer: Color(0xFF005047),
    onPrimaryContainer: Color(0xFF94F2E2),
    secondaryContainer: Color(0xFF244C46),
    onSecondaryContainer: Color(0xFFD4EFE8),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    warningContainer: Color(0xFF5B3C00),
    onWarningContainer: Color(0xFFFFE7B3),
    successContainer: Color(0xFF0A3D1F),
    onSuccessContainer: Color(0xFFC9F0D5),
    outline: Color(0xFF89938F),
    destination: Color(0xFFFF8A80),
  );

  static const light = SignalPalette(
    ink: Color(0xFFF8FAF9),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFEBF0EE),
    text: Color(0xFF191C1B),
    muted: Color(0xFF404947),
    beacon: Color(0xFF00796B),
    route: Color(0xFF00897B),
    good: Color(0xFF0A3D1F),
    moderate: Color(0xFF5B3C00),
    weak: Color(0xFF8A4F00),
    none: Color(0xFF59615E),
    sos: Color(0xFFB3261E),
    border: Color(0xFFC0C9C6),
    glass: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFB2EBE2),
    onPrimaryContainer: Color(0xFF00201C),
    secondaryContainer: Color(0xFFCDE8E3),
    onSecondaryContainer: Color(0xFF00201C),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    warningContainer: Color(0xFFFFE7B3),
    onWarningContainer: Color(0xFF5B3C00),
    successContainer: Color(0xFFC9F0D5),
    onSuccessContainer: Color(0xFF0A3D1F),
    outline: Color(0xFF6F7977),
    destination: Color(0xFFEA4335),
  );

  Color level(String level) => switch (level) {
    'good' => good,
    'moderate' => moderate,
    'weak' => weak,
    _ => none,
  };

  Color levelContainer(String level) => switch (level) {
    'good' => successContainer,
    'moderate' || 'weak' => warningContainer,
    _ => elevated,
  };

  Color onLevelContainer(String level) => switch (level) {
    'good' => onSuccessContainer,
    'moderate' || 'weak' => onWarningContainer,
    _ => text,
  };
}

class AppTheme {
  static ThemeData of(Brightness brightness) {
    final pal = brightness == Brightness.dark
        ? SignalPalette.dark
        : SignalPalette.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: pal.beacon,
          brightness: brightness,
        ).copyWith(
          primary: pal.beacon,
          onPrimary: brightness == Brightness.dark
              ? const Color(0xFF003731)
              : Colors.white,
          primaryContainer: pal.primaryContainer,
          onPrimaryContainer: pal.onPrimaryContainer,
          secondary: pal.route,
          onSecondary: brightness == Brightness.dark
              ? const Color(0xFF003733)
              : Colors.white,
          secondaryContainer: pal.secondaryContainer,
          onSecondaryContainer: pal.onSecondaryContainer,
          error: pal.sos,
          onError: brightness == Brightness.dark
              ? const Color(0xFF690005)
              : Colors.white,
          errorContainer: pal.errorContainer,
          onErrorContainer: pal.onErrorContainer,
          surface: pal.surface,
          onSurface: pal.text,
          surfaceContainer: pal.elevated,
          surfaceContainerHighest: brightness == Brightness.dark
              ? const Color(0xFF2A3431)
              : const Color(0xFFE4E9E7),
          onSurfaceVariant: pal.muted,
          outline: pal.outline,
          outlineVariant: pal.border,
        );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: pal.ink,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: pal.border,
      appBarTheme: AppBarTheme(
        backgroundColor: pal.ink,
        foregroundColor: pal.text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: pal.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: pal.elevated,
        indicatorColor: pal.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? pal.beacon
                : pal.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? pal.beacon
                : pal.muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: pal.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.surface,
        modalBackgroundColor: pal.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.beacon, width: 1.4),
        ),
        hintStyle: TextStyle(color: pal.muted),
      ),
      cardTheme: CardThemeData(
        color: pal.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pal.border),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: pal.surface,
        selectedColor: pal.secondaryContainer,
        side: BorderSide(color: pal.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: pal.text),
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

TextStyle dataStyle(
  BuildContext context, {
  double size = 14,
  FontWeight? weight,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w500,
    color: context.palette.text,
  );
}
