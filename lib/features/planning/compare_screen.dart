import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final routes = session.rankedRoutes();
        return Scaffold(
          appBar: AppBar(title: const Text('Compare routes')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                '${session.origin.name} to ${session.destination.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Ranked for ${session.routePref == 'fastest' ? 'shorter time' : session.routePref == 'balanced' ? 'a balance of time and signal' : 'better connectivity'}.',
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: 16),
              for (final route in routes) ...[
                _routeCard(context, ref, session, route, route.id == routes.first.id),
                const SizedBox(height: 12),
              ],
              const SectionLabel('Operators on the selected route'),
              Text(
                'Shown only where the mock drive has a score for that network.',
                style: TextStyle(color: context.palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final op in const ['jio', 'airtel', 'vi', 'bsnl'])
                _operatorBar(context, session.route, op),
            ],
          ),
        );
      },
    );
  }

  Widget _routeCard(
    BuildContext context,
    WidgetRef ref,
    Session session,
    JourneyRoute route,
    bool top,
  ) {
    final selected = session.selectedRouteId == route.id;
    final pal = context.palette;
    return Glass(
      color: pal.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (top) const SignalChip(level: 'good', label: 'Preferred'),
            ],
          ),
          const SizedBox(height: 4),
          Text(route.via, style: TextStyle(color: pal.muted)),
          const SizedBox(height: 8),
          Text(
            '${route.distanceKm.toStringAsFixed(0)} km · ${formatDuration(route.durationMin)} · score ${route.connectivityScore}',
            style: dataStyle(context),
          ),
          const SizedBox(height: 8),
          Text(route.outlook),
          const SizedBox(height: 8),
          _statRow(context, route.stats[session.operatorFilter] ?? route.stats['all']!),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: selected
                    ? null
                    : () => ref.read(sessionProvider.notifier).update(
                          (s) => s.copyWith(selectedRouteId: route.id),
                        ),
                child: Text(selected ? 'Selected' : 'Use this route'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  ref.read(sessionProvider.notifier).update(
                        (s) => s.copyWith(selectedRouteId: route.id),
                      );
                  await _save(context, ref, route);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, Map<String, int> stats) {
    return Row(
      children: [
        for (final level in const ['good', 'moderate', 'weak', 'none'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stats[level] ?? 0}%', style: dataStyle(context, size: 13)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: ((stats[level] ?? 0) / 100).clamp(0, 1),
                      color: context.palette.level(level),
                      backgroundColor: context.palette.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _operatorBar(BuildContext context, JourneyRoute route, String op) {
    final stats = route.stats[op];
    if (stats == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(operatorLabel(op), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final level in const ['good', 'moderate', 'weak', 'none'])
                    Expanded(
                      flex: stats[level] ?? 0,
                      child: ColoredBox(color: context.palette.level(level)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, JourneyRoute route) async {
    final name = TextEditingController(
      text: 'Hyderabad to Srisailam – ${route.name}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save journey'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save journey')),
        ],
      ),
    );
    if (saved != true) return;
    ref.read(sessionProvider.notifier).update((s) {
      return s.copyWith(
        trips: [
          SavedTrip(
            id: 't${DateTime.now().millisecondsSinceEpoch}',
            name: name.text.trim().isEmpty ? route.name : name.text.trim(),
            routeId: route.id,
            originId: s.originId,
            destinationId: s.destinationId,
            offlinePrepared: false,
            kind: 'saved',
          ),
          ...s.trips,
        ],
      );
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey saved')),
      );
      context.go('/trips');
    }
  }
}
