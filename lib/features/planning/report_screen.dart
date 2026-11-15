import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final route = session.route;
        final op = session.operatorFilter;
        final stats = route.stats[op] ?? route.stats['all']!;
        final pal = context.palette;
        final places = session.catalog.places;
        final offlineReady = session.trips.any(
          (trip) => trip.offlinePrepared && trip.routeId == route.id,
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Pre-trip report')),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: pal.ink,
                border: Border(top: BorderSide(color: pal.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/navigate'),
                      icon: const Icon(PhosphorIconsRegular.navigationArrow),
                      label: const Text('Start navigation'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: offlineReady
                          ? null
                          : () {
                              ref.read(sessionProvider.notifier).update((s) {
                                final existing = s.trips.indexWhere(
                                  (trip) => trip.routeId == route.id,
                                );
                                if (existing >= 0) {
                                  final next = [...s.trips];
                                  next[existing] = next[existing].copyWith(
                                    offlinePrepared: true,
                                  );
                                  return s.copyWith(trips: next);
                                }
                                return s.copyWith(
                                  trips: [
                                    SavedTrip(
                                      id: 'off${route.id}',
                                      name:
                                          '${session.origin.name} to ${session.destination.name}',
                                      routeId: route.id,
                                      originId: s.originId,
                                      destinationId: s.destinationId,
                                      offlinePrepared: true,
                                      kind: 'saved',
                                    ),
                                    ...s.trips,
                                  ],
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Route marked offline-ready for this demo; no map tiles were downloaded.',
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        offlineReady
                            ? PhosphorIconsRegular.checkCircle
                            : PhosphorIconsRegular.downloadSimple,
                      ),
                      label: Text(
                        offlineReady
                            ? 'Offline-ready in this demo'
                            : 'Mark offline-ready (demo)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 136),
              children: [
                Glass(
                  color: pal.elevated,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.origin.name} to ${session.destination.name}',
                        style: TextStyle(color: pal.muted),
                      ),
                      const SizedBox(height: 12),
                      Text(route.outlook),
                      const SizedBox(height: 8),
                      const SourceTag(source: 'estimated'),
                      const SizedBox(height: 12),
                      Text(
                        '${route.distanceKm.toStringAsFixed(0)} km · '
                        '${formatDuration(route.durationMin)} · ${operatorLabel(op)}',
                        style: dataStyle(
                          context,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeading(
                  'Signal along the drive',
                  subtitle: 'Estimated coverage for the selected network.',
                ),
                for (final level in const ['good', 'moderate', 'weak', 'none'])
                  _percent(context, level, stats[level] ?? 0),
                const SizedBox(height: 8),
                const SectionHeading('Route segments'),
                for (final segment in route.segments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(segment.label),
                    subtitle: Text(
                      '${segment.km.toStringAsFixed(0)} km · ${formatDuration(segment.min)}',
                    ),
                    trailing: SignalChip(
                      level: segment.levelFor(op),
                      compact: true,
                    ),
                  ),
                const SectionHeading(
                  'Blackspots',
                  subtitle: 'Plan ahead for limited or no service.',
                ),
                for (final spot in session.catalog.blackspots)
                  Glass(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${spot.lengthKm} km · about ${spot.durationMin} min',
                          style: dataStyle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(spot.warning),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionHeading('Recovery points'),
                ..._named(places, 'recovery'),
                const SectionHeading('Nearby services'),
                ..._named(places, 'hospital'),
                ..._named(places, 'police'),
                ..._named(places, 'fuel'),
                const SectionHeading(
                  'Before you leave',
                  subtitle: 'A few useful reminders for this route.',
                ),
                Glass(
                  child: Column(
                    children: [
                      for (final step in const [
                        'Save route details before signal drops.',
                        'Tell a preferred contact your arrival window.',
                        'Fuel up before the forest stretch.',
                        'Keep emergency numbers somewhere accessible.',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                PhosphorIconsRegular.arrowRight,
                                color: pal.beacon,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(step)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _percent(BuildContext context, String level, int value) {
    final label = switch (level) {
      'good' => 'Good',
      'moderate' => 'Moderate',
      'weak' => 'Weak',
      _ => 'No signal',
    };
    return Semantics(
      label: '$label signal coverage: $value percent',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(label)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: value / 100,
                    color: context.palette.level(level),
                    backgroundColor: context.palette.border,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('$value%', style: dataStyle(context, size: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _named(List<Place> places, String category) {
    return [
      for (final place in places.where((p) => p.category == category))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(categoryIcon(category)),
          title: Text(place.name),
          subtitle: Text(place.subtitle),
        ),
    ];
  }
}
