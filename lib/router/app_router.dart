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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/map',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
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
      GoRoute(
        path: '/search',
        builder: (c, s) =>
            SearchScreen(mode: s.uri.queryParameters['mode'] ?? 'destination'),
      ),
      GoRoute(path: '/report', builder: (c, s) => const ReportScreen()),
      GoRoute(path: '/compare', builder: (c, s) => const CompareScreen()),
      GoRoute(path: '/navigate', builder: (c, s) => const NavigationScreen()),
      GoRoute(
        path: '/trip/:id',
        builder: (c, s) => TripDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
});
