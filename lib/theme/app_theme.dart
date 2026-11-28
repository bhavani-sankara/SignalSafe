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
    ink: Color(0xFF0C1017),
    surface: Color(0xFF131922),
    elevated: Color(0xFF1B232F),
    text: Color(0xFFE4E9F1),
    muted: Color(0xFF95A1B5),
    beacon: Color(0xFF8AB4FF),
    route: Color(0xFF7AA9FF),
    good: Color(0xFF4CAF80),
    moderate: Color(0xFFFFB74D),
    weak: Color(0xFFFF8A65),
    none: Color(0xFF78909C),
    sos: Color(0xFFEF5350),
    border: Color(0xFF2A3445),
    glass: Color(0xFF171E29),
    primaryContainer: Color(0xFF1C3A7A),
    onPrimaryContainer: Color(0xFFD5E2FF),
    secondaryContainer: Color(0xFF1E2A42),
    onSecondaryContainer: Color(0xFFD6E1FB),
    errorContainer: Color(0xFF6E1A17),
    onErrorContainer: Color(0xFFFFCDD2),
    warningContainer: Color(0xFF4A2D00),
    onWarningContainer: Color(0xFFFFE0B2),
    successContainer: Color(0xFF0D3320),
    onSuccessContainer: Color(0xFFA5D6A7),
    outline: Color(0xFF4E5B72),
    destination: Color(0xFFFF7043),
  );

  static const light = SignalPalette(
    ink: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFEDF1F7),
    text: Color(0xFF101828),
    muted: Color(0xFF566174),
    beacon: Color(0xFF1F5BD6),
    route: Color(0xFF2563EB),
    good: Color(0xFF2E7D32),
    moderate: Color(0xFFE65100),
    weak: Color(0xFFBF360C),
    none: Color(0xFF455A64),
    sos: Color(0xFFC62828),
    border: Color(0xFFD7DDE7),
    glass: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE6FF),
    onPrimaryContainer: Color(0xFF0A2366),
    secondaryContainer: Color(0xFFE4EBFA),
    onSecondaryContainer: Color(0xFF0E2250),
    errorContainer: Color(0xFFFFCDD2),
    onErrorContainer: Color(0xFF4E0000),
    warningContainer: Color(0xFFFFE0B2),
    onWarningContainer: Color(0xFF3E1E00),
    successContainer: Color(0xFFC8E6C9),
    onSuccessContainer: Color(0xFF0A2E10),
    outline: Color(0xFF677289),
    destination: Color(0xFFE53935),
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
    final pal =
        brightness == Brightness.dark ? SignalPalette.dark : SignalPalette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: pal.beacon,
      brightness: brightness,
    ).copyWith(
      primary: pal.beacon,
      onPrimary:
          brightness == Brightness.dark ? const Color(0xFF002520) : Colors.white,
      primaryContainer: pal.primaryContainer,
      onPrimaryContainer: pal.onPrimaryContainer,
      secondary: pal.route,
      onSecondary:
          brightness == Brightness.dark ? const Color(0xFF002520) : Colors.white,
      secondaryContainer: pal.secondaryContainer,
      onSecondaryContainer: pal.onSecondaryContainer,
      error: pal.sos,
      onError:
          brightness == Brightness.dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: pal.errorContainer,
      onErrorContainer: pal.onErrorContainer,
      surface: pal.surface,
      onSurface: pal.text,
      surfaceContainer: pal.elevated,
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF263330)
          : const Color(0xFFDDE7E5),
      onSurfaceVariant: pal.muted,
      outline: pal.outline,
      outlineVariant: pal.border,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    // DM Sans applied style-by-style to avoid TextTheme? merge API issues
    TextStyle dm(double size, FontWeight weight,
            {double? letterSpacing, double? height}) =>
        GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: height,
        );

    final textTheme = base.textTheme.copyWith(
      displaySmall:
          dm(44, FontWeight.w700, letterSpacing: -1.5, height: 1.05),
      headlineLarge:
          dm(34, FontWeight.w700, letterSpacing: -0.5, height: 1.1),
      headlineMedium:
          dm(28, FontWeight.w600, letterSpacing: -0.3, height: 1.15),
      headlineSmall: dm(22, FontWeight.w600, height: 1.2),
      titleLarge: dm(18, FontWeight.w600, letterSpacing: -0.2),
      titleMedium: dm(16, FontWeight.w500, letterSpacing: -0.1, height: 1.4),
      titleSmall: dm(14, FontWeight.w500),
      bodyLarge: dm(15, FontWeight.w400, height: 1.5),
      bodyMedium: dm(14, FontWeight.w400, height: 1.5),
      bodySmall: dm(12, FontWeight.w400, height: 1.4),
      labelLarge: dm(13, FontWeight.w600, letterSpacing: 0.1),
      labelMedium: dm(12, FontWeight.w500),
      labelSmall: dm(11, FontWeight.w500, letterSpacing: 0.3),
    // Every style gets an explicit colour for this theme. Without it, text
    // that doesn't set its own colour falls back to whatever the platform
    // default is, which on some phones is white on our white surfaces.
    ).apply(bodyColor: pal.text, displayColor: pal.text);

    return base.copyWith(
      scaffoldBackgroundColor: pal.ink,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: pal.border,
      appBarTheme: AppBarTheme(
        backgroundColor: pal.ink,
        foregroundColor: pal.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: pal.text,
          fontWeight: FontWeight.w500,
          fontSize: 24,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: brightness == Brightness.dark
            ? pal.elevated
            : pal.surface,
        indicatorColor: pal.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
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
            size: 22,
            color: states.contains(WidgetState.selected)
                ? pal.beacon
                : pal.muted,
          ),
        ),
      ),
      // One filled pill per surface (the primary action). Everything else is
      // a light tonal pill with no border, so only one thing shouts.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
          backgroundColor: pal.secondaryContainer,
          foregroundColor: brightness == Brightness.dark
              ? pal.onSecondaryContainer
              : const Color(0xFF143E9C),
          side: BorderSide.none,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.surface,
        modalBackgroundColor: pal.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: pal.border,
        dragHandleSize: const Size(40, 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.elevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: pal.beacon, width: 1.5),
        ),
        hintStyle: TextStyle(color: pal.muted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: pal.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: pal.surface,
        selectedColor: pal.secondaryContainer,
        side: BorderSide(color: pal.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: pal.text,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        minLeadingWidth: 0,
        iconColor: pal.muted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? pal.beacon : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? pal.beacon.withValues(alpha: 0.35)
                : null),
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
  return GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    color: context.palette.text,
  );
}

/// Night palette used by turn-by-turn navigation, whatever the app theme is.
/// Deep navy instead of black so the map still reads as a map.
abstract final class NavPalette {
  static const night = Color(0xFF0B1626);
  static const surface = Color(0xFF13233A);
  static const raised = Color(0xFF1B2F4B);
  static const text = Color(0xFFE8F0FA);
  static const muted = Color(0xFF93A7C1);
  static const route = Color(0xFF7DB0FF);
  static const routeCasing = Color(0xFF123A80);
  static const instruction = Color(0xFF1F5BD6);
  static const instructionDeep = Color(0xFF16449F);
  static const warning = Color(0xFFFFB547);
  static const warningSurface = Color(0xFF3A2A10);
  static const good = Color(0xFF5FD89A);
}

/// Soft, short shadow used for floating chrome over the map.
List<BoxShadow> softShadow(BuildContext context, {double strength = 1}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: (dark ? 0.4 : 0.12) * strength),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: (dark ? 0.2 : 0.05) * strength),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
}
