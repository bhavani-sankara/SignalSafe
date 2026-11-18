import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Trips'),
            actions: [
              IconButton(
                tooltip: 'Add a place',
                onPressed: () => context.push('/search?mode=destination'),
                icon: const Icon(PhosphorIconsRegular.plus),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // ── Saved places row ──────────────────────────────────
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final place in session.catalog.savedPlaces)
                        _placeBubble(context, ref, place)
                            .animate(delay: (session.catalog.savedPlaces
                                        .indexOf(place) *
                                    60)
                                .ms)
                            .fadeIn(duration: 300.ms)
                            .slideX(
                                begin: 0.15,
                                end: 0,
                                duration: 320.ms,
                                curve: Curves.easeOut),
                      _newPlaceBubble(context),
                    ],
                  ),
                ),

                const SectionHeading('Saved journeys'),

                // ── Empty state ───────────────────────────────────────
                if (journeys.isEmpty)
                  _emptyJourneys(context, pal)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, end: 0),

                // ── Journey cards ─────────────────────────────────────
                for (var i = 0; i < journeys.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _tripCard(context, ref, session, journeys[i]),
                  )
                      .animate(delay: (i * 60).ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 340.ms,
                          curve: Curves.easeOut),

                // ── Recent searches ────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: SectionHeading('Recent searches')),
                    if (session.recents.isNotEmpty)
                      TextButton(
                        onPressed: () => ref
                            .read(sessionProvider.notifier)
                            .update((s) => s.copyWith(recents: const [])),
                        child: const Text('Clear'),
                      ),
                  ],
                ),

                if (session.recents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Places you search for will appear here.',
                      style: TextStyle(color: pal.muted),
                    ),
                  )
                else
                  for (final recent in session.recents)
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: pal.elevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          PhosphorIconsRegular.clockCounterClockwise,
                          color: pal.muted,
                          size: 18,
                        ),
                      ),
                      title: Text(recent,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Icon(PhosphorIconsRegular.arrowUpLeft,
                          color: pal.muted, size: 18),
                      onTap: () => context.go('/map'),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyJourneys(BuildContext context, SignalPalette pal) {
    return Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: pal.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(PhosphorIconsRegular.path, color: pal.beacon, size: 24),
          ),
          const SizedBox(height: 14),
          Text('Your next journey starts here.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
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

  Widget _placeBubble(
      BuildContext context, WidgetRef ref, Map<String, String> place) {
    final label = place['label']!.split(' · ');
    final isHome = label.first.toLowerCase() == 'home';
    final pal = context.palette;

    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(sessionProvider.notifier).update(
              (s) => s.copyWith(destinationId: place['id']));
          context.go('/map');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHome
                        ? [
                            pal.beacon.withValues(alpha: 0.2),
                            pal.beacon.withValues(alpha: 0.08),
                          ]
                        : [
                            pal.sos.withValues(alpha: 0.18),
                            pal.sos.withValues(alpha: 0.07),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHome
                        ? pal.beacon.withValues(alpha: 0.25)
                        : pal.sos.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  isHome
                      ? PhosphorIconsRegular.houseLine
                      : PhosphorIconsRegular.mapPinLine,
                  color: isHome ? pal.beacon : pal.sos,
                  size: 22,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newPlaceBubble(BuildContext context) {
    final pal = context.palette;
    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/search?mode=destination'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: pal.elevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: pal.border,
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Icon(PhosphorIconsRegular.plus,
                    color: pal.muted, size: 22),
              ),
              const SizedBox(height: 7),
              Text(
                'Add place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: pal.muted, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripCard(
      BuildContext context, WidgetRef ref, Session session, SavedTrip trip) {
    final route = session.catalog.routeById(trip.routeId);
    final origin = session.catalog.place(trip.originId);
    final destination = session.catalog.place(trip.destinationId);
    final pal = context.palette;
    final lowMin = route.segments
        .where((s) {
          final level = s.levelFor(session.operatorFilter);
          return level == 'none' || level == 'weak';
        })
        .fold<int>(0, (t, s) => t + s.min);
    final stats =
        route.stats[session.operatorFilter] ?? route.stats['all']!;
    final goodPct = stats['good'] ?? 0;
    final hasGoodSignal = goodPct >= 60;

    return Material(
      color: pal.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: pal.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map thumbnail with signal gradient header
            Stack(
              children: [
                const RoutePreview(height: 112),
                // Signal health gradient overlay at the bottom of preview
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (hasGoodSignal ? pal.successContainer : pal.warningContainer)
                              .withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Signal chip floating on the preview
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: SignalChip(
                    level: hasGoodSignal ? 'good' : 'moderate',
                    label: hasGoodSignal ? '$goodPct% good signal' : '$lowMin min low signal',
                    compact: true,
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${origin.name.split(',').first} → ${destination.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pal.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),

                  // Signal coverage bar
                  SignalCoverageBar(stats: stats, height: 7),

                  const SizedBox(height: 10),

                  // Stat pills
                  RouteStatRow(
                    distanceKm: route.distanceKm,
                    durationMin: route.durationMin,
                    lowSignalMin: lowMin,
                  ),

                  if (trip.offlinePrepared) ...[
                    const SizedBox(height: 10),
                    Tooltip(
                      message:
                          'This saved plan does not include downloaded map tiles.',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: pal.successContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIconsRegular.check,
                                size: 13, color: pal.onSuccessContainer),
                            const SizedBox(width: 5),
                            Text(
                              'Offline plan · demo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pal.onSuccessContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      TextButton(
                        onPressed: () => context.push('/trip/${trip.id}'),
                        child: const Text('Details'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _start(context, ref, trip),
                          child: const Text('Start'),
                        ),
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
    ref.read(sessionProvider.notifier).update(
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
