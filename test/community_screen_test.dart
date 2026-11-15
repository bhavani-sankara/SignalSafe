import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/features/community/community_screen.dart';

void main() {
  testWidgets('flagging a report keeps its content readable', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CommunityScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flag as outdated').first);
    await tester.pumpAndSettle();

    expect(find.text('Flagged as possibly outdated'), findsOneWidget);
    expect(find.text('BSNL surprisingly usable in town.'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove flag'), findsOneWidget);
  });
}
