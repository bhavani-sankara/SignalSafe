import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/theme/app_theme.dart';

void main() {
  // Text that doesn't set a colour inherits these. A null colour falls back
  // to the platform default, which on some phones is white on our white
  // light-theme cards.
  test('every text style has a theme colour', () {
    for (final b in Brightness.values) {
      final t = AppTheme.of(b).textTheme;
      final pal = b == Brightness.dark ? SignalPalette.dark : SignalPalette.light;
      for (final s in [
        t.displaySmall, t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall, t.bodyLarge, t.bodyMedium,
        t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall,
      ]) {
        expect(s?.color, pal.text, reason: '$b');
      }
    }
  });
}
