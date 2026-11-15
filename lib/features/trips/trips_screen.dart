import 'package:flutter/material.dart';
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
            .where((trip) => trip.kind == 'saved' || trip.offlinePrepared)
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Trips')),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const SectionHeading(
                  'Saved journeys',
                  subtitle: 'Routes you can pick up again.',
                ),
                if (journeys.isEmpty)
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(PhosphorIconsRegular.path),
                        const SizedBox(height: 8),
                        const Text('Your next journey starts with a route.'),
                        const SizedBox(height: 4),
                        Text(
                          'Compare routes and save one to keep it here.',
                          style: TextStyle(color: context.palette.muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/map'),
                          icon: const Icon(PhosphorIconsRegular.mapTrifold),
                          label: const Text('Find a route'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final trip in journeys) _tile(context, session, trip),
                const SectionHeading(
                  'Recent searches',
                  subtitle: 'Pick up where you left off.',
                ),
                if (session.recents.isEmpty)
                  Text(
                    'Places you search for will appear here.',
                    style: TextStyle(color: context.palette.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final recent in session.recents)
                        ActionChip(
                          avatar: const Icon(
                            PhosphorIconsRegular.clockCounterClockwise,
                            size: 16,
                          ),
                          label: Text(recent),
                          onPressed: () => context.go('/map'),
                        ),
                    ],
                  ),
                const SectionHeading(
                  'Frequent places',
                  subtitle: 'Places saved to your profile.',
                ),
                for (final item in session.catalog.savedPlaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListTile(
                        leading: const Icon(
                          PhosphorIconsRegular.mapPinLine,
                          size: 20,
                        ),
                        title: Text(item['label']!),
                        trailing: const Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 18,
                        ),
                        onTap: () {
                          ref
                              .read(sessionProvider.notifier)
                              .update(
                                (s) => s.copyWith(destinationId: item['id']),
                              );
                          context.go('/map');
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Session session, SavedTrip trip) {
    final route = session.catalog.routeById(trip.routeId);
    final origin = session.catalog.place(trip.originId);
    final destination = session.catalog.place(trip.destinationId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.path, size: 22),
              title: Text(trip.name),
              subtitle: Text(
                '${origin.name} to ${destination.name}\n'
                '${route.distanceKm.toStringAsFixed(0)} km · '
                '${formatDuration(route.durationMin)}',
              ),
              trailing: const Icon(PhosphorIconsRegular.caretRight, size: 18),
              onTap: () => context.push('/trip/${trip.id}'),
            ),
            if (trip.offlinePrepared)
              const Padding(
                padding: EdgeInsets.only(left: 64, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SignalChip(
                    level: 'good',
                    label: 'Offline ready',
                    compact: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
