import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/core/session.dart';
import 'package:signalsafe/features/navigation/navigation_screen.dart';
import 'package:signalsafe/theme/app_theme.dart';

void main() {
  testWidgets('navigation shows guidance, connectivity, and dock actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(catalogProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Brightness.light),
          home: const NavigationScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Head south on the Outer Ring Road'), findsOneWidget);
    expect(find.text('Then'), findsOneWidget);
    expect(find.text('Good · All networks · Estimated'), findsOneWidget);
    expect(find.text('Toward Srisailam'), findsNothing);
    expect(find.text('Mannanur – Dornala forest'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.byTooltip('End navigation'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand route details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Route connectivity'), findsOneWidget);

    await tester.tap(find.text('Drive'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });
}
