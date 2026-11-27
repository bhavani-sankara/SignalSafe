import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signalsafe/features/shell/app_shell.dart';

void main() {
  testWidgets('uses the floating bottom bar compactly and a rail when wide', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.bySemanticsLabel('Trips'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('trips page'), findsOneWidget);

    tester.view.physicalSize = const Size(800, 844);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
  });
}

GoRouter _router() {
  Widget page(String name) => Center(child: Text('$name page'));
  return GoRouter(
    initialLocation: '/map',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final name in ['map', 'trips', 'safety', 'community', 'profile'])
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/$name', builder: (c, s) => page(name)),
              ],
            ),
        ],
      ),
    ],
  );
}
