import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/core/session.dart';
import 'package:signalsafe/features/profile/profile_screen.dart';

void main() {
  testWidgets('dark theme switch is available and updates its selected state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final themeSwitch = find.widgetWithText(SwitchListTile, 'Dark theme');
    expect(tester.widget<SwitchListTile>(themeSwitch).value, isFalse);

    await tester.tap(themeSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(container.read(sessionProvider)?.darkMode, isTrue);

    await tester.scrollUntilVisible(
      find.text('Stay near services'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Stay near services'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(container.read(sessionProvider)?.avoidLongBlackspots, isTrue);
    expect(container.read(sessionProvider)?.stayNearServices, isTrue);
  });
}
