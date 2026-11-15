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
          appBar: AppBar(
            title: const Text('Trips'),
            actions: [
              IconButton(
                tooltip: 'Add a place',
                onPressed: () => context.push('/search?mode=destination'),
                icon: const Icon(PhosphorIconsRegular.plus),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
              children: [
                SizedBox(
                  height: 126,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final place in session.catalog.savedPlaces)
                        _placeBubble(context, ref, place),
                      _newPlaceBubble(context),
                    ],
                  ),
                ),
                const SectionHeading('Saved journeys'),
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
                  for (final trip in journeys)
                    _tile(context, ref, session, trip),
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
                      style: TextStyle(color: context.palette.muted),
                    ),
                  )
                else
                  for (final recent in session.recents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: context.palette.elevated,
                        child: Icon(
                          PhosphorIconsRegular.clockCounterClockwise,
                          color: context.palette.text,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        recent,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(
                        PhosphorIconsRegular.arrowUpLeft,
                        color: context.palette.muted,
                      ),
                      onTap: () => context.go('/map'),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeBubble(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> place,
  ) {
    final label = place['label']!.split(' · ');
    final isHome = label.first.toLowerCase() == 'home';
    final pal = context.palette;
    return SizedBox(
      width: 106,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ref
              .read(sessionProvider.notifier)
              .update((s) => s.copyWith(destinationId: place['id']));
          context.go('/map');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isHome
                    ? pal.good.withValues(alpha: 0.18)
                    : pal.sos.withValues(alpha: 0.14),
                child: Icon(
                  isHome
                      ? PhosphorIconsRegular.houseLine
                      : PhosphorIconsRegular.mapPinLine,
                  color: isHome ? pal.beacon : pal.sos,
                  size: 25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label.first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (label.length > 1)
                Text(
                  label.skip(1).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 12),
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
      width: 106,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/search?mode=destination'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: pal.elevated,
                child: Icon(
                  PhosphorIconsRegular.plus,
                  color: pal.muted,
                  size: 25,
                ),
              ),
              const SizedBox(height: 8),
              const Text('New place', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SavedTrip trip,
  ) {
    final route = session.catalog.routeById(trip.routeId);
    final origin = session.catalog.place(trip.originId);
    final destination = session.catalog.place(trip.destinationId);
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: pal.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: pal.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RoutePreview(height: 120),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${origin.name.split(',').first} to ${destination.name} · '
                      '${route.distanceKm.toStringAsFixed(0)} km · '
                      '${formatDuration(route.durationMin)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        if (trip.offlinePrepared)
                          Tooltip(
                            message: 'This saved plan does not include downloaded map tiles.',
                            child: Chip(
                              avatar: Icon(
                                PhosphorIconsRegular.check,
                                size: 18,
                                color: pal.onSuccessContainer,
                              ),
                              label: const Text('Offline plan · demo'),
                              backgroundColor: pal.successContainer,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: pal.onSuccessContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/trip/${trip.id}'),
                              child: const Text('Details'),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () => _start(context, ref, trip),
                              child: const Text('Start'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
