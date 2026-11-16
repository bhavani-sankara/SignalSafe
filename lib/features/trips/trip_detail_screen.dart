import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/frosted.dart';
import '../../widgets/hud.dart';
import '../../widgets/route_mini_map.dart';
import '../../widgets/session_gate.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final matches = session.trips.where((t) => t.id == id);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Journey')),
            body: const Center(child: Text('This journey was removed.')),
          );
        }
        final trip = matches.first;
        final route = session.catalog.routeById(trip.routeId);
        final origin = session.catalog.place(trip.originId);
        final destination = session.catalog.place(trip.destinationId);
        final pal = context.palette;
        final stats =
            route.stats[session.operatorFilter] ?? route.stats['all']!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Journey'),
            actions: [
              IconButton(
                tooltip: 'Rename',
                onPressed: () => _rename(context, ref, trip.name),
                icon: const Icon(PhosphorIconsRegular.pencilSimple),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => _remove(context, ref, trip.name),
                icon: const Icon(PhosphorIconsRegular.trash),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: () {
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
                    },
                    icon: const Icon(PhosphorIconsFill.navigationArrow),
                    label: const Text('Start navigation'),
                  ),
                ),
              ),
            ),
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Hero(
                    tag: 'trip-map-${trip.id}',
                    child: RouteMiniMap(
                      route: route,
                      context: session.catalog.routes,
                      operator: session.operatorFilter,
                      height: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${origin.name} to ${destination.name}',
                        style: TextStyle(color: pal.text, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'via ${route.via}',
                        style: TextStyle(color: pal.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatTile(
                      label: 'Distance',
                      value: '${route.distanceKm.toStringAsFixed(0)} km',
                      icon: PhosphorIconsRegular.ruler,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Drive time',
                      value: formatDuration(route.durationMin),
                      icon: PhosphorIconsRegular.clock,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Signal score',
                      value: '${route.connectivityScore}',
                      icon: PhosphorIconsRegular.cellSignalHigh,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverageStrip(stats: stats, height: 8),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            PhosphorIconsRegular.info,
                            size: 18,
                            color: pal.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              route.outlook,
                              style: TextStyle(color: pal.text, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const SourceTag(source: 'estimated'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    'Signal by route segment',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < route.segments.length; i++)
                        SegmentRow(
                          segment: route.segments[i],
                          level: route.segments[i].levelFor(
                            session.operatorFilter,
                          ),
                          first: i == 0,
                          last: i == route.segments.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename journey'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(sessionProvider.notifier).update((s) {
      return s.copyWith(
        trips: [
          for (final trip in s.trips)
            if (trip.id == id)
              trip.copyWith(
                name: controller.text.trim().isEmpty
                    ? trip.name
                    : controller.text.trim(),
              )
            else
              trip,
        ],
      );
    });
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved journey?'),
        content: Text('“$name” will be removed from your saved trips.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep journey'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.sos,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref
        .read(sessionProvider.notifier)
        .update(
          (s) => s.copyWith(
            trips: s.trips.where((trip) => trip.id != id).toList(),
          ),
        );
    if (context.mounted) context.pop();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: pal.beacon),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: pal.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: TextStyle(color: pal.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
