import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/core/session.dart';
import 'package:signalsafe/features/map/map_screen.dart';
import 'package:signalsafe/theme/app_theme.dart';

void main() {
  testWidgets('community report map markers expose accessible targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(catalogProvider.future);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Brightness.light),
          home: const MapScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final polygons = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(polygons.polygons, isNotEmpty);
    expect(
      polygons.polygons.every(
        (polygon) =>
            polygon.color ==
            SignalPalette.light.moderate.withValues(alpha: 0.16),
      ),
      isTrue,
    );
    final filterChip = tester.getRect(find.byType(FilterChip).first);
    final layerButton = tester.getRect(find.byTooltip('Map layers'));
    expect(layerButton.top, greaterThanOrEqualTo(filterChip.bottom));

    final marker = find.bySemanticsLabel(
      RegExp('Moderate signal report, Airtel'),
    );
    expect(marker, findsOneWidget);
    expect(tester.getRect(marker).size, const Size(48, 48));
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
