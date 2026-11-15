import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/features/trips/trips_screen.dart';

void main() {
  testWidgets('an offline saved journey is listed only once', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad to Srisailam – Weekend Trip'), findsOneWidget);
    expect(find.textContaining('Offline plan'), findsOneWidget);
    expect(find.text('Prepared offline'), findsNothing);
  });
}
