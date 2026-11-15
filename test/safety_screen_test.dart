import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/features/safety/safety_screen.dart';

void main() {
  testWidgets('safety screen labels demo behavior clearly', (tester) async {
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
  });
}
