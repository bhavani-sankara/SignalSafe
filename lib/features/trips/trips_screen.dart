import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        final saved = session.trips.where((t) => t.kind == 'saved').toList();
        final offline = session.trips.where((t) => t.offlinePrepared).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Trips')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const SectionLabel('Saved journeys'),
              if (saved.isEmpty)
                const Text('Save a route from the map to keep it here.')
              else
                for (final trip in saved) _tile(context, ref, session, trip),
              const SectionLabel('Prepared offline'),
              if (offline.isEmpty)
                Text(
                  'Prepare a journey from the pre-trip report.',
                  style: TextStyle(color: context.palette.muted),
                )
              else
                for (final trip in offline) _tile(context, ref, session, trip),
              const SectionLabel('Recent searches'),
              if (session.recents.isEmpty)
                const Text('Searches you make on the map show up here.')
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final recent in session.recents)
                      ActionChip(
                        label: Text(recent),
                        onPressed: () => context.go('/map'),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              const SectionLabel('Frequent places'),
              for (final item in session.catalog.savedPlaces)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['label']!),
                  onTap: () {
                    ref.read(sessionProvider.notifier).update(
                          (s) => s.copyWith(destinationId: item['id']),
                        );
                    context.go('/map');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Session session, SavedTrip trip) {
    final route = session.catalog.routeById(trip.routeId);
    return Card(
      color: context.palette.surface,
      child: ListTile(
        title: Text(trip.name),
        subtitle: Text(
          '${route.distanceKm.toStringAsFixed(0)} km · ${formatDuration(route.durationMin)}'
          '${trip.offlinePrepared ? ' · Offline pack' : ''}',
        ),
        onTap: () => context.push('/trip/${trip.id}'),
      ),
    );
  }
}
