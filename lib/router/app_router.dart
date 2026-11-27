import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/community/community_screen.dart';
import '../features/map/map_screen.dart';
import '../features/map/search_screen.dart';
import '../features/navigation/navigation_screen.dart';
import '../features/planning/compare_screen.dart';
import '../features/planning/report_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/safety/safety_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/trips/trip_detail_screen.dart';
import '../features/trips/trips_screen.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/map',
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            FadingBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/map', builder: (c, s) => const MapScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/trips', builder: (c, s) => const TripsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/safety', builder: (c, s) => const SafetyScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (c, s) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Search cross-fades in (no slide), which reads as instant.
      GoRoute(
        path: '/search',
        pageBuilder: (c, s) => _fadePage(
          s,
          SearchScreen(mode: s.uri.queryParameters['mode'] ?? 'destination'),
        ),
      ),
      GoRoute(
        path: '/report',
        pageBuilder: (c, s) => _risePage(s, const ReportScreen()),
      ),
      GoRoute(
        path: '/compare',
        pageBuilder: (c, s) => _risePage(s, const CompareScreen()),
      ),
      // Navigation fades through night navy: the light app dims into the
      // dark driving view.
      GoRoute(
        path: '/navigate',
        pageBuilder: (c, s) => _nightPage(s, const NavigationScreen()),
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (c, s) =>
            _risePage(s, TripDetailScreen(id: s.pathParameters['id']!)),
      ),
    ],
  );
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.standard,
    reverseTransitionDuration: Motion.quick,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.enter);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _risePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: Motion.standard,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _nightPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondary, child) {
      // First half: navy veil fades over the light app.
      // Second half: the dark navigation screen fades in under it.
      final veil = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 45),
        TweenSequenceItem(tween: ConstantTween(1), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 45),
      ]).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
      final page = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.45, 1, curve: Curves.easeOut),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(opacity: page, child: child),
          IgnorePointer(
            child: FadeTransition(
              opacity: veil,
              child: const ColoredBox(color: NavPalette.night),
            ),
          ),
        ],
      );
    },
  );
}

/// Keeps every tab alive (like an IndexedStack) but cross-fades between
/// them in ~200 ms instead of hard-cutting.
class FadingBranchContainer extends StatelessWidget {
  const FadingBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.quick);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(
            active: i == currentIndex,
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.active,
    required this.duration,
    required this.child,
  });

  final bool active;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: ExcludeSemantics(
          excluding: !active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: duration,
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}
