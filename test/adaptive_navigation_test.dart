import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signalsafe/features/shell/app_shell.dart';

void main() {
  testWidgets('uses bottom navigation compactly and a rail when expanded', (
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

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    tester.view.physicalSize = const Size(800, 844);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

GoRouter _router() {
  const branches = ['map', 'trips', 'safety', 'community', 'profile'];
  return GoRouter(
    initialLocation: '/map',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final branch in branches)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/$branch',
                  builder: (context, state) =>
                      Scaffold(body: Center(child: Text(branch))),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
