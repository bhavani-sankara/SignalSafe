import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/features/safety/safety_screen.dart';

void main() {
  testWidgets('safety screen uses honest demo disclosure and held SOS', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SafetyScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo mode'), findsOneWidget);
    expect(
      find.textContaining('This demo does not share live location'),
      findsOneWidget,
    );
    expect(find.text('Sharing live'), findsNothing);

    final button = find.text('Press and hold for SOS options');
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.textContaining('This demo cannot send an SMS'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('This demo cannot send an SMS'), findsOneWidget);
  });
}
