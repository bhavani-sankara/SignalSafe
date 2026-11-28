import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/core/session.dart';
import 'package:signalsafe/features/map/map_screen.dart';
import 'package:signalsafe/theme/app_theme.dart';
import 'package:signalsafe/widgets/spring_sheet.dart';

Future<ProviderContainer> _pumpMap(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(catalogProvider.future));
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
  return container;
}

void main() {
  testWidgets('community report map markers expose accessible targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpMap(tester);

    final polygons = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(polygons.polygons, isNotEmpty);

    // Reports near the start of the trip are on screen in explore mode.
    final marker = find.bySemanticsLabel(RegExp('signal report, Jio'));
    expect(marker, findsWidgets);
    expect(tester.getRect(marker.first).size, const Size(48, 48));
    expect(find.byTooltip('Map layers'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('explore opens on the search pill and an around-you sheet', (
    tester,
  ) async {
    await _pumpMap(tester);
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Continue your trip'), findsOneWidget);
    expect(find.textContaining('Signal Check'), findsOneWidget);
    expect(find.byTooltip('Directions'), findsOneWidget);
    expect(find.byType(SpringSheet), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('directions runs the staged reveal and shows network scores', (
    tester,
  ) async {
    final container = await _pumpMap(tester);
    // The "Make plans" suggestion pill opens directions.
    await tester.tap(find.textContaining('to Srisailam?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Skeleton first, the from/to card replaces the search pill.
    expect(find.text('Finding the best-signal route…'), findsOneWidget);
    expect(find.byTooltip('Swap start and destination'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Finding the best-signal route…'), findsNothing);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Avoid blackspots'), findsOneWidget);
    // Networks only: no "All" tab in directions.
    expect(find.text('All'), findsNothing);
    expect(find.text('Airtel'), findsWidgets);

    // Network tabs switch the operator.
    await tester.tap(find.text('Airtel').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(sessionProvider)?.operatorFilter, 'airtel');
    await tester.tap(find.text('Jio').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(sessionProvider)?.operatorFilter, 'jio');

    // Back returns to explore.
    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Where to?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a quick flick up takes the sheet to full and hides search', (
    tester,
  ) async {
    await _pumpMap(tester);
    final sheet = tester.state(find.byType(SpringSheet));
    expect(sheet, isNotNull);
    await tester.fling(find.text('Continue your trip'), const Offset(0, -300), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byTooltip('Show map'), findsOneWidget);
    // Search chrome has faded out and no longer takes taps.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Where to?'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
