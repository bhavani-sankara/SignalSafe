import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  String? _category;
  bool _towers = true;
  bool _essentials = true;
  bool _blackspots = true;
  bool _fitted = false;

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      builder: (context, session) {
        if (!_fitted) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fit(session));
        }
        final pal = context.palette;
        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: session.here,
                  initialZoom: 11,
                  onLongPress: (_, point) =>
                      _droppedPin(context, session, point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.signalsafe.app',
                  ),
                  if (session.overlayOn && _blackspots)
                    PolygonLayer(
                      polygons: [
                        for (final spot in session.catalog.blackspots)
                          Polygon(
                            points: spot.points,
                            color: pal.none.withValues(alpha: 0.35),
                            borderColor: pal.weak,
                            borderStrokeWidth: 1.4,
                          ),
                      ],
                    ),
                  if (session.overlayOn)
                    PolylineLayer(polylines: _ribbons(session, pal)),
                  MarkerLayer(markers: _markers(context, session, pal)),
                  const RichAttributionWidget(
                    attributions: [TextSourceAttribution('OpenStreetMap')],
                  ),
                ],
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _searchBar(context, session),
                          const SizedBox(height: 10),
                          _chips(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 168,
                child: Column(
                  children: [
                    RoundIconButton(
                      icon: PhosphorIconsRegular.crosshair,
                      tooltip: 'Recenter',
                      onTap: () => _map.move(session.here, 13),
                    ),
                    const SizedBox(height: 10),
                    RoundIconButton(
                      icon: PhosphorIconsRegular.stack,
                      tooltip: 'Map layers',
                      selected: session.overlayOn,
                      onTap: () => _layers(context, session),
                    ),
                    const SizedBox(height: 10),
                    RoundIconButton(
                      icon: PhosphorIconsRegular.broadcast,
                      tooltip: 'Network operator',
                      onTap: () => _operators(context, session),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _journeySheet(context, session),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Polyline> _ribbons(Session session, SignalPalette pal) {
    final route = session.route;
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    return [
      for (final other in session.catalog.routes)
        if (other.id != route.id)
          Polyline(
            points: other.points,
            color: pal.muted.withValues(alpha: 0.55),
            strokeWidth: 4,
          ),
      for (var i = 0; i < slices.length; i++)
        Polyline(
          points: slices[i],
          color: pal.level(route.segments[i].levelFor(session.operatorFilter)),
          strokeWidth: 7,
          pattern: route.segments[i].levelFor(session.operatorFilter) == 'none'
              ? const StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
    ];
  }

  List<Marker> _markers(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
    final markers = <Marker>[
      _pin(
        session.here,
        pal.beacon,
        PhosphorIconsFill.navigationArrow,
        semanticLabel: 'Current location, ${session.origin.name}',
        onTap: () => _placeSheet(context, session.origin),
      ),
      _pin(
        session.destination.point,
        pal.route,
        PhosphorIconsFill.mapPin,
        semanticLabel: 'Destination, ${session.destination.name}',
        onTap: () => _placeSheet(context, session.destination),
      ),
    ];
    if (_towers) {
      for (final tower in session.catalog.towers) {
        if (session.operatorFilter != 'all' &&
            tower.operator != session.operatorFilter) {
          continue;
        }
        markers.add(
          _pin(
            tower.point,
            _opColor(tower.operator),
            PhosphorIconsFill.broadcast,
            semanticLabel:
                '${operatorLabel(tower.operator)} tower, ${tower.name}',
            onTap: () => _towerSheet(context, tower),
          ),
        );
      }
    }
    if (_essentials) {
      for (final place in session.catalog.places) {
        if (place.id == session.originId || place.id == session.destinationId) {
          continue;
        }
        if (_category != null && place.category != _category) continue;
        if (_category == null &&
            place.category != 'recovery' &&
            place.category != 'hospital' &&
            place.category != 'police' &&
            place.category != 'fuel') {
          continue;
        }
        markers.add(
          _pin(
            place.point,
            place.category == 'recovery' ? pal.good : pal.text,
            categoryIcon(place.category),
            semanticLabel: place.name,
            onTap: () => _placeSheet(context, place),
          ),
        );
      }
    }
    if (session.communityLayerOn) {
      for (final report in session.reports) {
        if (session.flaggedIds.contains(report.id)) continue;
        if (session.operatorFilter != 'all' &&
            report.operator != session.operatorFilter) {
          continue;
        }
        markers.add(
          Marker(
            point: report.point,
            width: 22,
            height: 22,
            child: GestureDetector(
              onTap: () => _reportSheet(context, report),
              child: Container(
                decoration: BoxDecoration(
                  color: pal.level(report.level),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  Marker _pin(
    LatLng point,
    Color color,
    IconData icon, {
    required String semanticLabel,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, size: 15, color: const Color(0xFF06201C)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context, Session session) {
    final pal = context.palette;
    return Material(
      color: pal.glass,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/search?mode=destination'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.magnifyingGlass, color: pal.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${session.origin.name}  →  ${session.destination.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pal.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips(BuildContext context) {
    const items = [
      ('hospital', 'Hospitals'),
      ('police', 'Police'),
      ('fuel', 'Fuel'),
      ('hotel', 'Hotels'),
      ('restaurant', 'Food'),
      ('atm', 'ATMs'),
      ('recovery', 'Recovery'),
      ('blackspot', 'Weak signal'),
    ];
    return SizedBox(
      height: 40,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.88, 1],
        ).createShader(bounds),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = _category == items[i].$1;
            return FilterChip(
              label: Text(items[i].$2),
              selected: selected,
              onSelected: (_) => setState(() {
                _category = selected ? null : items[i].$1;
                _essentials = true;
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _journeySheet(BuildContext context, Session session) {
    final pal = context.palette;
    final route = session.route;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Glass(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SourceTag(source: 'estimated'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${route.distanceKm.toStringAsFixed(0)} km · ${formatDuration(route.durationMin)} · ${operatorLabel(session.operatorFilter)}',
                    style: dataStyle(context, size: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    route.outlook,
                    style: TextStyle(color: pal.muted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ref
                                .read(sessionProvider.notifier)
                                .update(
                                  (s) => s.copyWith(
                                    selectedRouteId: route.id,
                                    navProgress: 0.08,
                                  ),
                                );
                            context.push('/navigate');
                          },
                          child: const Text('Start navigation'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Compare routes',
                        onPressed: () => context.push('/compare'),
                        icon: const Icon(PhosphorIconsRegular.arrowsLeftRight),
                      ),
                      IconButton(
                        tooltip: 'Pre-trip report',
                        onPressed: () => context.push('/report'),
                        icon: const Icon(PhosphorIconsRegular.clipboardText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _fit(Session session) {
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(session.route.points),
        padding: const EdgeInsets.fromLTRB(36, 150, 36, 230),
      ),
    );
  }

  Future<void> _layers(BuildContext context, Session session) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Widget tile(
              String title,
              bool value,
              ValueChanged<bool> onChanged,
            ) {
              return SwitchListTile(
                title: Text(title),
                value: value,
                onChanged: (v) {
                  onChanged(v);
                  setSheet(() {});
                  setState(() {});
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tile('Connectivity overlay', session.overlayOn, (v) {
                    ref
                        .read(sessionProvider.notifier)
                        .update((s) => s.copyWith(overlayOn: v));
                    session = ref.read(sessionProvider)!;
                  }),
                  tile('Community reports', session.communityLayerOn, (v) {
                    ref
                        .read(sessionProvider.notifier)
                        .update((s) => s.copyWith(communityLayerOn: v));
                    session = ref.read(sessionProvider)!;
                  }),
                  tile('Mobile towers', _towers, (v) => _towers = v),
                  tile('Essential places', _essentials, (v) => _essentials = v),
                  tile('Blackspot areas', _blackspots, (v) => _blackspots = v),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _operators(BuildContext context, Session session) {
    const ops = ['all', 'jio', 'airtel', 'vi', 'bsnl'];
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final op in ops)
                ListTile(
                  title: Text(operatorLabel(op)),
                  trailing: session.operatorFilter == op
                      ? Icon(
                          PhosphorIconsFill.check,
                          color: context.palette.beacon,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(sessionProvider.notifier)
                        .update((s) => s.copyWith(operatorFilter: op));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _placeSheet(BuildContext context, Place place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                place.subtitle,
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: 8),
              const SourceTag(source: 'estimated'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ref.read(sessionProvider.notifier).update((s) {
                          final recent = [
                            place.name,
                            ...s.recents.where((r) => r != place.name),
                          ].take(8).toList();
                          return s.copyWith(
                            destinationId: place.id,
                            recents: recent,
                          );
                        });
                        Navigator.pop(context);
                        _map.move(place.point, 13);
                      },
                      child: const Text('Set as destination'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _towerSheet(BuildContext context, Tower tower) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tower.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${operatorLabel(tower.operator)} · ${tower.tech}'),
              const SizedBox(height: 6),
              Text(tower.detail, style: dataStyle(context)),
              const SizedBox(height: 8),
              SourceTag(source: tower.source),
              const SizedBox(height: 8),
              Text(
                '${tower.point.latitude.toStringAsFixed(4)}, ${tower.point.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: context.palette.muted),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reportSheet(BuildContext context, SignalReport report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SourceTag(source: 'community'),
              const SizedBox(height: 8),
              SignalChip(level: report.level),
              const SizedBox(height: 8),
              Text(
                '${operatorLabel(report.operator)} · ${report.tech} · ${agoLabel(report.minutesAgo)}',
              ),
              const SizedBox(height: 6),
              Text(report.comment),
              const SizedBox(height: 6),
              Text(
                'Agreement ${(report.agreement * 100).round()}%',
                style: dataStyle(context, size: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  void _droppedPin(BuildContext context, Session session, LatLng point) {
    Place? nearest;
    var best = double.infinity;
    for (final place in session.catalog.places) {
      final meters = distance(point, place.point);
      if (meters < best) {
        best = meters;
        nearest = place;
      }
    }
    if (nearest == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nearest known place: ${nearest.name}'),
        action: SnackBarAction(
          label: 'Use',
          onPressed: () {
            ref
                .read(sessionProvider.notifier)
                .update((s) => s.copyWith(destinationId: nearest!.id));
            _map.move(nearest!.point, 13);
          },
        ),
      ),
    );
  }
}

Color _opColor(String operator) => switch (operator) {
  'jio' => const Color(0xFF1F6BFF),
  'airtel' => const Color(0xFFE10600),
  'vi' => const Color(0xFF7A3EAE),
  'bsnl' => const Color(0xFFD6A100),
  _ => const Color(0xFF6BA8FF),
};
