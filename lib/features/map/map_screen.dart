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
                            color: pal.good.withValues(alpha: 0.16),
                            borderColor: pal.good.withValues(alpha: 0.55),
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
          color: route.segments[i].levelFor(session.operatorFilter) == 'none'
              ? pal.moderate
              : pal.level(route.segments[i].levelFor(session.operatorFilter)),
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
            _categoryColor(place.category, pal),
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
      color: pal.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _routeStop(
                    context,
                    icon: PhosphorIconsRegular.navigationArrow,
                    color: pal.beacon,
                    name: session.origin.name,
                    onTap: () => context.push('/search?mode=origin'),
                  ),
                  Divider(
                    height: 1,
                    indent: 32,
                    color: pal.border.withValues(alpha: 0.8),
                  ),
                  _routeStop(
                    context,
                    icon: PhosphorIconsRegular.mapPinLine,
                    color: pal.sos,
                    name: session.destination.name,
                    onTap: () => context.push('/search?mode=destination'),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Swap start and destination',
              onPressed: () => ref
                  .read(sessionProvider.notifier)
                  .update(
                    (s) => s.copyWith(
                      originId: s.destinationId,
                      destinationId: s.originId,
                    ),
                  ),
              icon: Icon(
                PhosphorIconsRegular.arrowsLeftRight,
                color: pal.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeStop(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String name,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
    final pal = context.palette;
    const items = [
      ('hospital', 'Hospitals', Color(0xFFE7483B)),
      ('police', 'Police', Color(0xFF3E7BCC)),
      ('fuel', 'Fuel', Color(0xFFE58A00)),
      ('hotel', 'Hotels', Color(0xFF9A4DCE)),
      ('restaurant', 'Food', Color(0xFFB9682B)),
      ('atm', 'ATMs', Color(0xFF476B9B)),
      ('recovery', 'Recovery', Color(0xFF16845B)),
      ('blackspot', 'Weak signal', Color(0xFFC55D00)),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = _category == item.$1;
          return FilterChip(
            avatar: Icon(categoryIcon(item.$1), size: 18, color: item.$3),
            label: Text(item.$2),
            selected: selected,
            backgroundColor: pal.surface,
            selectedColor: pal.beacon.withValues(alpha: 0.18),
            checkmarkColor: pal.beacon,
            side: BorderSide(
              color: selected ? pal.beacon : pal.border.withValues(alpha: 0.5),
            ),
            onSelected: (_) => setState(() {
              _category = selected ? null : item.$1;
              _essentials = true;
            }),
          );
        },
      ),
    );
  }

  Widget _journeySheet(BuildContext context, Session session) {
    final pal = context.palette;
    final route = session.route;
    final stats = route.stats[session.operatorFilter] ?? route.stats['all']!;
    final lowSignalSegments = route.segments
        .where(
          (segment) =>
              segment.levelFor(session.operatorFilter) == 'none' ||
              segment.levelFor(session.operatorFilter) == 'weak',
        )
        .toList();
    final lowSignalMinutes = lowSignalSegments.fold<int>(
      0,
      (total, segment) => total + segment.min,
    );
    final lowSignalStart = lowSignalSegments.isEmpty
        ? null
        : lowSignalSegments.first.label.split(' – ').first;
    final lowSignalEnd = lowSignalSegments.isEmpty
        ? null
        : lowSignalSegments.last.label.split(' – ').last;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Material(
              color: pal.surface,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: pal.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${route.durationMin ~/ 60} h ${route.durationMin % 60} min',
                          style: TextStyle(
                            color: pal.beacon,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '(${route.distanceKm.toStringAsFixed(0)} km)',
                          style: TextStyle(color: pal.muted, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${route.name} · Estimated · '
                      '${operatorLabel(session.operatorFilter)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Estimated signal coverage by signal level',
                      child: Row(
                        children: [
                          for (final level in const [
                            'good',
                            'moderate',
                            'weak',
                            'none',
                          ])
                            Expanded(
                              flex: (stats[level] ?? 0).clamp(1, 100).toInt(),
                              child: Container(
                                height: 8,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: pal.level(level),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lowSignalStart == null
                                ? 'No weak areas'
                                : 'From $lowSignalStart',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 12),
                          ),
                        ),
                        Text(
                          '$lowSignalMinutes min low/no signal',
                          maxLines: 1,
                          style: TextStyle(
                            color: pal.moderate,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lowSignalEnd == null ? '' : 'To $lowSignalEnd',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
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
                            icon: const Icon(
                              PhosphorIconsRegular.navigationArrow,
                            ),
                            label: const Text('Start navigation'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Offline map downloads are not available in this demo.',
                                  ),
                                ),
                              ),
                          icon: const Icon(PhosphorIconsRegular.downloadSimple),
                          label: const Text('Offline'),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Pre-trip report',
                          onPressed: () => context.push('/report'),
                          icon: const Icon(PhosphorIconsRegular.clipboardText),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => context.push('/compare'),
                        icon: const Icon(
                          PhosphorIconsRegular.arrowsLeftRight,
                          size: 18,
                        ),
                        label: const Text('Compare routes'),
                      ),
                    ),
                  ],
                ),
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

Color _categoryColor(String category, SignalPalette palette) =>
    switch (category) {
      'hospital' => const Color(0xFFE7483B),
      'police' => palette.route,
      'fuel' => const Color(0xFFE58A00),
      'hotel' => const Color(0xFF9A4DCE),
      'recovery' => palette.good,
      'blackspot' => palette.moderate,
      _ => palette.text,
    };

Color _opColor(String operator) => switch (operator) {
  'jio' => const Color(0xFF1F6BFF),
  'airtel' => const Color(0xFFE10600),
  'vi' => const Color(0xFF7A3EAE),
  'bsnl' => const Color(0xFFD6A100),
  _ => const Color(0xFF6BA8FF),
};
