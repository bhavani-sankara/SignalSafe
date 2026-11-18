import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:signalsafe/core/session.dart';
import 'package:signalsafe/features/safety/safety_screen.dart';
import 'package:signalsafe/theme/app_theme.dart';

void main() {
  testWidgets('dark SOS action uses the theme error foreground', (
    tester,
  ) async {
    final darkTheme = AppTheme.of(Brightness.dark);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(catalogProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Brightness.light),
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
          home: const SafetyScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final label = tester.widget<Text>(
      find.text('Press and hold for SOS options'),
    );
    expect(label.style?.color, darkTheme.colorScheme.onError);
    final sirenIcons = tester.widgetList<Icon>(
      find.byIcon(PhosphorIconsFill.siren),
    );
    expect(
      sirenIcons.every((icon) => icon.color == darkTheme.colorScheme.onError),
      isTrue,
    );
  });
}
