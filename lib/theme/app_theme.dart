import 'package:flutter/cupertino.dart'
    show
        CupertinoPageTransitionsBuilder,
        CupertinoTextThemeData,
        CupertinoThemeData;
import 'package:flutter/material.dart';

const kFont = 'Inter';

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
    ink: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    elevated: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF98989F),
    beacon: Color(0xFF80D8CC),
    route: Color(0xFF80CBC4),
    good: Color(0xFFC9F0D5),
    moderate: Color(0xFFFFE7B3),
    weak: Color(0xFFFFD8A8),
    none: Color(0xFFBAC4C1),
    sos: Color(0xFFFFB4AB),
    border: Color(0xFF38383A),
    glass: Color(0xFF1C1C1E),
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
    outline: Color(0xFF8E8E93),
    destination: Color(0xFFFF8A80),
  );

  static const light = SignalPalette(
    ink: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFE9E9EE),
    text: Color(0xFF000000),
    muted: Color(0xFF6C6C70),
    beacon: Color(0xFF00796B),
    route: Color(0xFF00897B),
    good: Color(0xFF0A3D1F),
    moderate: Color(0xFF5B3C00),
    weak: Color(0xFF8A4F00),
    none: Color(0xFF59615E),
    sos: Color(0xFFB3261E),
    border: Color(0xFFD1D1D6),
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
    outline: Color(0xFF8E8E93),
    destination: Color(0xFFEA4335),
  );

  Color level(String level) => switch (level) {
    'good' => good,
    'moderate' => moderate,
    'weak' => weak,
    _ => none,
  };

  /// Bright fill for bars, strips and route lines (not for text).
  Color levelFill(String level) => switch (level) {
    'good' => route,
    'moderate' => const Color(0xFFE0A100),
    'weak' => const Color(0xFFE07A00),
    _ => const Color(0xFF9AA3A0),
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
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: kFont,
      // iOS behaviour everywhere: bouncing scroll, edge-swipe back,
      // Cupertino switches/indicators for adaptive widgets.
      platform: TargetPlatform.iOS,
    );
    TextStyle? t(
      TextStyle? b,
      double size,
      FontWeight w,
      double ls, [
      double? h,
    ]) => b?.copyWith(
      fontFamily: kFont,
      fontSize: size,
      fontWeight: w,
      letterSpacing: ls,
      height: h,
    );
    // Apple's type ramp (Large Title 34, Title 28/22/20, Headline 17,
    // Body 17, Callout 16, Subhead 15, Footnote 13, Caption 12/11).
    final tt = base.textTheme;
    final textTheme = tt.copyWith(
      displaySmall: t(tt.displaySmall, 34, FontWeight.w700, -0.8),
      headlineLarge: t(tt.headlineLarge, 34, FontWeight.w700, -0.8),
      headlineMedium: t(tt.headlineMedium, 34, FontWeight.w700, -0.8),
      headlineSmall: t(tt.headlineSmall, 28, FontWeight.w700, -0.6, 1.15),
      titleLarge: t(tt.titleLarge, 22, FontWeight.w700, -0.4),
      titleMedium: t(tt.titleMedium, 17, FontWeight.w600, -0.3),
      titleSmall: t(tt.titleSmall, 15, FontWeight.w600, -0.2),
      bodyLarge: t(tt.bodyLarge, 17, FontWeight.w400, -0.3, 1.3),
      bodyMedium: t(tt.bodyMedium, 15, FontWeight.w400, -0.2, 1.33),
      bodySmall: t(tt.bodySmall, 13, FontWeight.w400, -0.05),
      labelLarge: t(tt.labelLarge, 15, FontWeight.w600, -0.2),
      labelMedium: t(tt.labelMedium, 13, FontWeight.w500, -0.05),
      labelSmall: t(tt.labelSmall, 11, FontWeight.w500, 0.05),
    );
    final cupertinoText = TextStyle(
      fontFamily: kFont,
      color: pal.text,
      fontSize: 17,
      letterSpacing: -0.3,
    );
    return base.copyWith(
      scaffoldBackgroundColor: pal.ink,
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: pal.beacon,
        brightness: brightness,
        textTheme: CupertinoTextThemeData(
          primaryColor: pal.beacon,
          textStyle: cupertinoText,
          navTitleTextStyle: cupertinoText.copyWith(
            fontWeight: FontWeight.w600,
          ),
          navLargeTitleTextStyle: cupertinoText.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          actionTextStyle: cupertinoText.copyWith(color: pal.beacon),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: pal.border,
      dividerTheme: DividerThemeData(
        color: pal.border,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: pal.ink,
        foregroundColor: pal.text,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: pal.text),
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 58,
        backgroundColor: pal.surface,
        indicatorColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelPadding: const EdgeInsets.only(top: 2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: kFont,
            fontSize: 10.5,
            letterSpacing: 0.05,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? pal.beacon
                : pal.outline,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? pal.beacon
                : pal.outline,
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
        surfaceTintColor: Colors.transparent,
        dragHandleColor: pal.outline.withValues(alpha: 0.45),
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: pal.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: pal.beacon, width: 1.4),
        ),
        hintStyle: TextStyle(color: pal.muted),
      ),
      cardTheme: CardThemeData(
        color: pal.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: pal.muted,
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: pal.text),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: pal.muted,
          fontSize: 13,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFFE0E5E3)
            : const Color(0xFF1F2624),
        contentTextStyle: TextStyle(
          color: brightness == Brightness.dark
              ? const Color(0xFF191C1B)
              : Colors.white,
          fontSize: 14,
        ),
        actionTextColor: brightness == Brightness.dark
            ? pal.primaryContainer
            : const Color(0xFF80D8CC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: pal.surface,
          selectedBackgroundColor: pal.primaryContainer,
          selectedForegroundColor: pal.onPrimaryContainer,
          side: BorderSide(color: pal.border),
          shape: const StadiumBorder(),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : pal.outline.withValues(alpha: 0.6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: pal.primaryContainer,
        foregroundColor: pal.onPrimaryContainer,
        elevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: pal.surface,
        selectedColor: pal.primaryContainer,
        side: BorderSide(color: pal.border.withValues(alpha: 0.7)),
        shape: const StadiumBorder(),
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
