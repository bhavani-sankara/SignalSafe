import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
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
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Glass(
                  color: context.palette.elevated,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${origin.name} to ${destination.name}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.via,
                        style: TextStyle(color: context.palette.muted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${route.distanceKm.toStringAsFixed(0)} km · '
                        '${formatDuration(route.durationMin)} · '
                        'score ${route.connectivityScore}',
                        style: dataStyle(context, size: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(route.outlook),
                      const SizedBox(height: 8),
                      const SourceTag(source: 'estimated'),
                    ],
                  ),
                ),
                const SectionHeading('Signal by route segment'),
                for (final segment in route.segments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(segment.label),
                    subtitle: Text(
                      '${segment.km.toStringAsFixed(0)} km · '
                      '${formatDuration(segment.min)}',
                    ),
                    trailing: SignalChip(
                      level: segment.levelFor(session.operatorFilter),
                      compact: true,
                    ),
                  ),
                FilledButton(
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
                  child: const Text('Start navigation'),
                ),
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
