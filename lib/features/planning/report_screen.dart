import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        return Scaffold(
          appBar: AppBar(title: const Text('Pre-trip report')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(route.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${session.origin.name} → ${session.destination.name}',
                style: TextStyle(color: pal.muted),
              ),
              const SizedBox(height: 12),
              Text(route.outlook),
              const SizedBox(height: 8),
              const SourceTag(source: 'estimated'),
              const SizedBox(height: 16),
              Text(
                '${route.distanceKm.toStringAsFixed(0)} km · ${formatDuration(route.durationMin)} · ${operatorLabel(op)}',
                style: dataStyle(context, size: 16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Signal along the drive'),
              for (final level in const ['good', 'moderate', 'weak', 'none'])
                _percent(context, level, stats[level] ?? 0),
              const SizedBox(height: 8),
              for (final segment in route.segments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(segment.label),
                  subtitle: Text('${segment.km.toStringAsFixed(0)} km · ${formatDuration(segment.min)}'),
                  trailing: SignalChip(
                    level: segment.levelFor(op),
                    compact: true,
                  ),
                ),
              const SectionLabel('Blackspots'),
              for (final spot in session.catalog.blackspots)
                Glass(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              const SectionLabel('Recovery points'),
              ..._named(places, 'recovery'),
              const SectionLabel('Hospitals, police, fuel'),
              ..._named(places, 'hospital'),
              ..._named(places, 'police'),
              ..._named(places, 'fuel'),
              const SectionLabel('Before you leave'),
              for (final step in const [
                'Download this route while you still have signal.',
                'Tell a preferred contact your arrival window.',
                'Fuel up at Kalwakurthy — the forest stretch has no pumps.',
                'Keep SOS numbers written down, not only on the phone.',
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: session.trips.any((t) => t.offlinePrepared && t.routeId == route.id),
                  onChanged: (_) {},
                  title: Text(step),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  ref.read(sessionProvider.notifier).update((s) {
                    final existing = s.trips.indexWhere((t) => t.routeId == route.id);
                    if (existing >= 0) {
                      final next = [...s.trips];
                      next[existing] = next[existing].copyWith(offlinePrepared: true);
                      return s.copyWith(trips: next);
                    }
                    return s.copyWith(
                      trips: [
                        SavedTrip(
                          id: 'off${route.id}',
                          name: '${session.origin.name} to ${session.destination.name}',
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
                    const SnackBar(content: Text('Journey prepared for offline use')),
                  );
                },
                child: const Text('Prepare offline pack'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push('/navigate'),
                child: const Text('Start navigation'),
              ),
            ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          SizedBox(width: 40, child: Text('$value%', style: dataStyle(context, size: 13))),
        ],
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
