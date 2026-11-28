import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hud.dart';
import '../../widgets/route_map_preview.dart';
import '../../widgets/session_gate.dart';
import '../map/map_widgets.dart';
import '../map/route_details.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final journeys = session.trips
            .where((t) => t.kind == 'saved' || t.offlinePrepared)
            .toList();
        final pal = context.palette;
        final reduced = Motion.reduced(context);

        Widget enter(Widget w, int i) => reduced
            ? w
            : w
                  .animate(delay: (50 * i).ms)
                  .fadeIn(duration: 280.ms, curve: Motion.enter)
                  .slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 320.ms,
                    curve: Motion.enter,
                  );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: MaxWidthContent(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trips',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add a place',
                          onPressed: () =>
                              context.push('/search?mode=destination'),
                          style: IconButton.styleFrom(
                            backgroundColor: pal.secondaryContainer,
                          ),
                          icon: Icon(
                            PhosphorIconsRegular.plus,
                            color: pal.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Saved places as pills ───────────────────────────────
                  enter(
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        children: [
                          for (final place in session.catalog.savedPlaces) ...[
                            _placePill(context, ref, place),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/search?mode=destination'),
                            icon: const Icon(
                              PhosphorIconsRegular.plus,
                              size: 16,
                            ),
                            label: const Text('Add place'),
                          ),
                        ],
                      ),
                    ),
                    0,
                  ),

                  SheetSectionTitle(
                    'Saved journeys',
                    subtitle: journeys.length > 1
                        ? '${journeys.length} saved · swipe for more'
                        : null,
                  ),

                  if (journeys.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: enter(_emptyJourneys(context, pal), 1),
                    )
                  else
                    SizedBox(
                      height: 392,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: journeys.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final w = MediaQuery.sizeOf(context).width.clamp(
                            300.0,
                            560.0,
                          );
                          return SizedBox(
                            // ~86% wide so a second card peeks in.
                            width: journeys.length > 1 ? w * 0.86 : w - 32,
                            child: enter(
                              _tripCard(context, ref, session, journeys[i]),
                              i + 1,
                            ),
                          );
                        },
                      ),
                    ),

                  // ── Recent searches ───────────────────────────────────
                  SheetSectionTitle(
                    'Recent searches',
                    trailing: session.recents.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => ref
                                .read(sessionProvider.notifier)
                                .update((s) => s.copyWith(recents: const [])),
                            child: const Text('Clear'),
                          ),
                  ),
                  if (session.recents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Places you search for will appear here.',
                        style: TextStyle(color: pal.muted),
                      ),
                    )
                  else
                    for (final recent in session.recents)
                      InkWell(
                        onTap: () => context.go('/map'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: pal.elevated,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIconsRegular.clockCounterClockwise,
                                  color: pal.muted,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  recent,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Icon(
                                PhosphorIconsRegular.arrowUpLeft,
                                color: pal.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyJourneys(BuildContext context, SignalPalette pal) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: pal.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIconsRegular.path, color: pal.beacon, size: 28),
          const SizedBox(height: 12),
          Text(
            'Your next journey starts here.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare routes on the map and save one to keep it here.',
            style: TextStyle(color: pal.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/map'),
            icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
            label: const Text('Find a route'),
          ),
        ],
      ),
    );
  }

  Widget _placePill(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> place,
  ) {
    final label = place['label']!.split(' · ');
    final isHome = label.first.toLowerCase() == 'home';
    final pal = context.palette;
    return Material(
      color: pal.surface,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          ref
              .read(sessionProvider.notifier)
              .update((s) => s.copyWith(destinationId: place['id']));
          context.go('/map');
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: softShadow(context),
            color: pal.surface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isHome
                      ? pal.secondaryContainer
                      : pal.destination.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHome
                      ? PhosphorIconsFill.houseLine
                      : PhosphorIconsFill.mapPin,
                  size: 15,
                  color: isHome ? pal.beacon : pal.destination,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.first,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripCard(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SavedTrip trip,
  ) {
    final route = session.catalog.routeById(trip.routeId);
    final origin = session.catalog.place(trip.originId);
    final destination = session.catalog.place(trip.destinationId);
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lowMin = lowSignalMinutes(route, session.operatorFilter);
    final score = networkScore(route, session.operatorFilter);

    return Material(
      color: pal.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/trip/${trip.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big rounded "photo" of the route with floating badges.
            Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Real map, fitted to the route (static, loads once).
                    RouteMapPreview(
                      route: route,
                      op: session.operatorFilter,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _FrostedBadge(
                        icon: PhosphorIconsFill.clock,
                        label: formatDuration(route.durationMin),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _FrostedBadge(
                        icon: PhosphorIconsFill.cellSignalHigh,
                        iconColor: scoreColor(pal, score),
                        label: '$score signal',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MetaLine([
                    '${origin.name.split(',').first} → ${destination.name}',
                    '${route.distanceKm.toStringAsFixed(0)} km',
                  ]),
                  const SizedBox(height: 12),
                  MiniSignalBars(
                    route: route,
                    op: session.operatorFilter == 'all'
                        ? session.preferredOperator
                        : session.operatorFilter,
                    height: 30,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (lowMin > 0)
                        Flexible(
                          child: Text(
                            '$lowMin min low/no signal on this route',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dark ? pal.moderate : pal.onWarningContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (trip.offlinePrepared) ...[
                    const SizedBox(height: 8),
                    Tooltip(
                      message:
                          'This saved plan does not include downloaded map tiles.',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsFill.checkCircle,
                            size: 15,
                            color: pal.good,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Offline plan · demo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.good,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _start(context, ref, trip),
                        icon: const Icon(
                          PhosphorIconsFill.navigationArrow,
                          size: 17,
                        ),
                        label: const Text('Start'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => context.push('/trip/${trip.id}'),
                        child: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref, SavedTrip trip) {
    ref
        .read(sessionProvider.notifier)
        .update(
          (s) => s.copyWith(
            selectedRouteId: trip.routeId,
            originId: trip.originId,
            destinationId: trip.destinationId,
            navProgress: 0.05,
          ),
        );
    context.push('/navigate');
  }
}

/// Small frosted label laid over a route image.
class _FrostedBadge extends StatelessWidget {
  const _FrostedBadge({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? const Color(0xFF0D1B18)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B18),
            ),
          ),
        ],
      ),
    );
  }
}
