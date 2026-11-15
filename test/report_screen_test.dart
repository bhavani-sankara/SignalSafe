import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/features/planning/report_screen.dart';

void main() {
  testWidgets('report actions stay available without fake checklist toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Start navigation'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.toLowerCase().contains('offline-ready') ?? false),
      ),
      findsOneWidget,
    );
  });
}
