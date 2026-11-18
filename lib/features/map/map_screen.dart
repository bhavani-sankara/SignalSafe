import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

// ---------------------------------------------------------------------------
// Snap positions (as fractions of screen height)
// ---------------------------------------------------------------------------
const double _kSnapCollapsed  = 0.14;  // just handle + ETA line
const double _kSnapHalf       = 0.38;  // signal bar + action buttons visible
const double _kSnapFull       = 0.82;  // full detail — all operators, segments

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map        = MapController();
  final _sheetCtrl  = DraggableScrollableController();

  String? _category;
  bool _towers     = true;
  bool _essentials = true;
  bool _blackspots = true;
  bool _fitted     = false;

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _snapTo(double size) {
    _sheetCtrl.animateTo(
      size,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      builder: (context, session) {
        if (!_fitted) {
          _fitted = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _fit(session));
        }
        final pal = context.palette;

        return Scaffold(
          body: Stack(
            children: [
              // ── Full-bleed map ──────────────────────────────────────
              Positioned.fill(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: session.here,
                    initialZoom: 11,
                    onLongPress: (_, pt) =>
                        _droppedPin(context, session, pt),
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
                              color: pal.moderate.withValues(alpha: 0.14),
                              borderColor:
                                  pal.moderate.withValues(alpha: 0.5),
                              borderStrokeWidth: 1.5,
                            ),
                        ],
                      ),
                    if (session.overlayOn)
                      PolylineLayer(polylines: _ribbons(session, pal)),
                    MarkerLayer(
                        markers: _markers(context, session, pal)),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap')
                      ],
                    ),
                  ],
                ),
              ),

              // ── Search bar + chips ──────────────────────────────────
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
                          const SizedBox(height: 8),
                          _chips(context),
                        ],
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(
                    begin: -0.08,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),

              // ── Right-rail controls ─────────────────────────────────
              Positioned(
                right: 12,
                top: 200,
                child: Column(
                  children: [
                    RoundIconButton(
                      icon: PhosphorIconsRegular.stack,
                      tooltip: 'Map layers',
                      onTap: () => _layers(context, session),
                    ),
                    const SizedBox(height: 8),
                    RoundIconButton(
                      icon: PhosphorIconsRegular.wifiHigh,
                      tooltip: session.overlayOn
                          ? 'Hide signal overlay'
                          : 'Show signal overlay',
                      selected: session.overlayOn,
                      onTap: () => ref
                          .read(sessionProvider.notifier)
                          .update((s) =>
                              s.copyWith(overlayOn: !s.overlayOn)),
                    ),
                    const SizedBox(height: 8),
                    RoundIconButton(
                      icon: PhosphorIconsRegular.crosshair,
                      tooltip: 'My location',
                      onTap: () => _map.move(session.here, 13),
                    ),
                    const SizedBox(height: 8),
                    RoundIconButton(
                      icon: PhosphorIconsRegular.broadcast,
                      tooltip: 'Network operator',
                      onTap: () => _operators(context, session),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideX(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),
              ),

              // ── Draggable journey sheet ─────────────────────────────
              _JourneySheet(
                session: session,
                sheetCtrl: _sheetCtrl,
                onSnapTo: _snapTo,
                onStart: () {
                  ref.read(sessionProvider.notifier).update(
                        (s) => s.copyWith(
                          selectedRouteId: session.route.id,
                          navProgress: 0.08,
                        ),
                      );
                  context.push('/navigate');
                },
                onCompare: () => context.push('/compare'),
                onReport: () => context.push('/report'),
                onLayers: () => _layers(context, session),
                onOperator: () => _operators(context, session),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOut,
                  ),
            ],
          ),
        );
      },
    );
  }

  // ── Route ribbons ──────────────────────────────────────────────────

  List<Polyline> _ribbons(Session session, SignalPalette pal) {
    final route  = session.route;
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    return [
      for (final other in session.catalog.routes)
        if (other.id != route.id)
          Polyline(
            points: other.points,
            color: pal.muted.withValues(alpha: 0.4),
            strokeWidth: 3.5,
          ),
      for (var i = 0; i < slices.length; i++) ...[
        Polyline(points: slices[i], color: Colors.white, strokeWidth: 12),
        Polyline(
          points: slices[i],
          color: _isLowSignal(
                  route.segments[i].levelFor(session.operatorFilter))
              ? pal.moderate
              : pal.route,
          strokeWidth: 7,
          pattern: _isLowSignal(
                  route.segments[i].levelFor(session.operatorFilter))
              ? const StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
      ],
    ];
  }

  bool _isLowSignal(String level) => level == 'none' || level == 'weak';

  // ── Markers ────────────────────────────────────────────────────────

  List<Marker> _markers(
      BuildContext context, Session session, SignalPalette pal) {
    final route  = session.route;
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    final markers = <Marker>[
      _pin(session.here, pal.beacon, PhosphorIconsFill.navigationArrow,
          semanticLabel:
              'Current location, ${session.origin.name}',
          onTap: () => _placeSheet(context, session.origin)),
      _destinationPin(context, session, pal),
    ];

    final firstGap = route.segments.indexWhere(
      (s) => _isLowSignal(s.levelFor(session.operatorFilter)),
    );
    if (firstGap >= 0 && slices[firstGap].isNotEmpty) {
      final seg      = route.segments[firstGap];
      final noSignal = seg.levelFor(session.operatorFilter) == 'none';
      markers.add(Marker(
        point: slices[firstGap][slices[firstGap].length ~/ 2],
        width: 160,
        height: 42,
        alignment: Alignment.centerLeft,
        child: Semantics(
          label:
              '${seg.min} min ${noSignal ? 'no-signal' : 'weak-signal'} section',
          child: Material(
            color: pal.warningContainer,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.wifiSlash,
                      size: 15, color: pal.onWarningContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${seg.min} min '
                      '${noSignal ? 'no signal' : 'weak'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pal.onWarningContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    if (_towers) {
      for (final tower in session.catalog.towers) {
        if (session.operatorFilter != 'all' &&
            tower.operator != session.operatorFilter) { continue; }
        markers.add(_pin(
          tower.point,
          _opColor(tower.operator),
          PhosphorIconsFill.broadcast,
          semanticLabel:
              '${operatorLabel(tower.operator)} tower, ${tower.name}',
          onTap: () => _towerSheet(context, tower),
        ));
      }
    }

    if (_essentials) {
      for (final place in session.catalog.places) {
        if (place.id == session.originId ||
            place.id == session.destinationId) { continue; }
        if (_category != null && place.category != _category) { continue; }
        if (_category == null &&
            place.category != 'recovery' &&
            place.category != 'hospital' &&
            place.category != 'police' &&
            place.category != 'fuel') { continue; }
        markers.add(_pin(
          place.point,
          place.category == 'hospital'
              ? pal.sos
              : _categoryColor(place.category, pal),
          place.category == 'hospital'
              ? PhosphorIconsRegular.firstAid
              : categoryIcon(place.category),
          semanticLabel: place.name,
          onTap: () => _placeSheet(context, place),
          iconColor: place.category == 'hospital'
              ? Colors.white
              : pal.onPrimaryContainer,
        ));
      }
    }

    if (session.communityLayerOn) {
      for (final report in session.reports) {
        if (session.flaggedIds.contains(report.id)) { continue; }
        if (session.operatorFilter != 'all' &&
            report.operator != session.operatorFilter) { continue; }
        markers.add(Marker(
          point: report.point,
          width: 48,
          height: 48,
          child: Semantics(
            button: true,
            label: '${_levelWord(report.level)} signal report, '
                '${operatorLabel(report.operator)}, '
                '${agoLabel(report.minutesAgo)}',
            onTap: () => _reportSheet(context, report),
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _reportSheet(context, report),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: context.palette.level(report.level),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }

    return markers;
  }

  String _levelWord(String level) => switch (level) {
        'good'     => 'Good',
        'moderate' => 'Moderate',
        'weak'     => 'Weak',
        _          => 'No',
      };

  Marker _destinationPin(
      BuildContext context, Session session, SignalPalette pal) {
    return Marker(
      point: session.destination.point,
      width: 48,
      height: 56,
      child: Semantics(
        button: true,
        label: 'Destination, ${session.destination.name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _placeSheet(context, session.destination),
          child: Center(
            child: Icon(PhosphorIconsFill.mapPin,
                size: 40, color: pal.destination),
          ),
        ),
      ),
    );
  }

  Marker _pin(
    LatLng point,
    Color color,
    IconData icon, {
    required String semanticLabel,
    VoidCallback? onTap,
    Color? iconColor,
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
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  Icon(icon, size: 15, color: iconColor ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context, Session session) {
    final pal  = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pal.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          // ← tighter vertical padding = shorter search bar
          padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const Positioned(
                      left: 10,
                      top: 28,
                      bottom: 28,
                      child: CustomPaint(
                        painter: _DottedConnectorPainter(),
                        size: Size(2, 28),
                      ),
                    ),
                    Column(
                      children: [
                        _routeStop(
                          context,
                          icon: PhosphorIconsRegular.navigationArrow,
                          color: pal.beacon,
                          name: session.origin.name,
                          onTap: () =>
                              context.push('/search?mode=origin'),
                        ),
                        _routeStop(
                          context,
                          icon: PhosphorIconsFill.mapPin,
                          color: pal.destination,
                          name: session.destination.name,
                          onTap: () =>
                              context.push('/search?mode=destination'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: pal.border,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
              IconButton(
                tooltip: 'Swap start and destination',
                onPressed: () =>
                    ref.read(sessionProvider.notifier).update(
                          (s) => s.copyWith(
                            originId: s.destinationId,
                            destinationId: s.originId,
                          ),
                        ),
                icon: Icon(PhosphorIconsRegular.arrowsLeftRight,
                    color: pal.muted, size: 18),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          // ← tighter row height
          height: 40,
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 14,
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

  // ── Category chips ─────────────────────────────────────────────────

  Widget _chips(BuildContext context) {
    final pal = context.palette;
    const items = [
      ('hospital',  'Hospitals',   Color(0xFFE7483B)),
      ('police',    'Police',      Color(0xFF3E7BCC)),
      ('fuel',      'Fuel',        Color(0xFFE58A00)),
      ('hotel',     'Hotels',      Color(0xFF9A4DCE)),
      ('restaurant','Food',        Color(0xFFB9682B)),
      ('atm',       'ATMs',        Color(0xFF476B9B)),
      ('recovery',  'Recovery',    Color(0xFF16845B)),
      ('blackspot', 'Weak signal', Color(0xFFC55D00)),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item     = items[i];
          final selected = _category == item.$1;
          return GestureDetector(
            onTap: () => setState(() {
              _category  = selected ? null : item.$1;
              _essentials = true;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    selected ? pal.secondaryContainer : pal.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? pal.beacon : pal.border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? []
                    : [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(categoryIcon(item.$1),
                      size: 13,
                      color: selected ? pal.beacon : item.$3),
                  const SizedBox(width: 5),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? pal.beacon : pal.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Map utils ──────────────────────────────────────────────────────

  void _fit(Session session) {
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(session.route.points),
        padding: const EdgeInsets.fromLTRB(36, 160, 36, 220),
      ),
    );
  }

  // ── Bottom sheets (layers / operators / place / tower / report) ────

  Future<void> _layers(BuildContext context, Session session) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheet) {
          Widget tile(
              String title, bool value, ValueChanged<bool> cb) {
            return SwitchListTile(
              title: Text(title),
              value: value,
              onChanged: (v) {
                cb(v);
                setSheet(() {});
                setState(() {});
              },
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text('Map layers',
                      style:
                          Theme.of(context).textTheme.titleMedium),
                ),
                tile('Connectivity overlay', session.overlayOn, (v) {
                  ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(overlayOn: v));
                  session = ref.read(sessionProvider)!;
                }),
                tile('Community reports', session.communityLayerOn,
                    (v) {
                  ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(communityLayerOn: v));
                  session = ref.read(sessionProvider)!;
                }),
                tile('Mobile towers', _towers,
                    (v) => _towers = v),
                tile('Essential places', _essentials,
                    (v) => _essentials = v),
                tile('Blackspot areas', _blackspots,
                    (v) => _blackspots = v),
              ],
            ),
          );
        });
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Network operator',
                    style:
                        Theme.of(context).textTheme.titleMedium),
              ),
              for (final op in ops)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 2),
                  title: Text(operatorLabel(op)),
                  trailing: session.operatorFilter == op
                      ? Icon(PhosphorIconsFill.check,
                          color: context.palette.beacon)
                      : null,
                  onTap: () {
                    ref.read(sessionProvider.notifier).update(
                        (s) => s.copyWith(operatorFilter: op));
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
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
        final pal = context.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pal.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(categoryIcon(place.category),
                        color: pal.beacon, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        Text(place.subtitle,
                            style: TextStyle(
                                color: pal.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SourceTag(source: 'estimated'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(sessionProvider.notifier).update((s) {
                      final recent = [
                        place.name,
                        ...s.recents
                            .where((r) => r != place.name),
                      ].take(8).toList();
                      return s.copyWith(
                          destinationId: place.id,
                          recents: recent);
                    });
                    Navigator.pop(context);
                    _map.move(place.point, 13);
                  },
                  icon: const Icon(
                      PhosphorIconsRegular.navigationArrow,
                      size: 18),
                  label: const Text('Set as destination'),
                ),
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
        final pal = context.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _opColor(tower.operator)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(PhosphorIconsRegular.broadcast,
                        color: _opColor(tower.operator), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tower.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        Text(
                          '${operatorLabel(tower.operator)} · ${tower.tech}',
                          style: TextStyle(color: pal.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(tower.detail, style: dataStyle(context)),
              const SizedBox(height: 8),
              SourceTag(source: tower.source),
              const SizedBox(height: 6),
              Text(
                '${tower.point.latitude.toStringAsFixed(4)}, '
                '${tower.point.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: pal.muted, fontSize: 13),
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
        final pal = context.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pal.levelContainer(report.level),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: SignalBars(level: report.level)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SignalChip(level: report.level),
                        const SizedBox(height: 4),
                        Text(
                          '${operatorLabel(report.operator)} · ${report.tech} · ${agoLabel(report.minutesAgo)}',
                          style: TextStyle(
                              color: pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(report.comment,
                    style: TextStyle(color: pal.text, height: 1.5)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const SourceTag(source: 'community'),
                  const Spacer(),
                  Text('${(report.agreement * 100).round()}% agree',
                      style: dataStyle(context, size: 13)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _droppedPin(
      BuildContext context, Session session, LatLng point) {
    Place? nearest;
    var best = double.infinity;
    for (final place in session.catalog.places) {
      final m = distance(point, place.point);
      if (m < best) {
        best = m;
        nearest = place;
      }
    }
    if (nearest == null) return;
    final n = nearest;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nearest: ${n.name}'),
        action: SnackBarAction(
          label: 'Use',
          onPressed: () {
            ref
                .read(sessionProvider.notifier)
                .update((s) => s.copyWith(destinationId: n.id));
            _map.move(n.point, 13);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draggable journey sheet
// ---------------------------------------------------------------------------

class _JourneySheet extends StatelessWidget {
  const _JourneySheet({
    required this.session,
    required this.sheetCtrl,
    required this.onSnapTo,
    required this.onStart,
    required this.onCompare,
    required this.onReport,
    required this.onLayers,
    required this.onOperator,
  });

  final Session  session;
  final DraggableScrollableController sheetCtrl;
  final void Function(double) onSnapTo;
  final VoidCallback onStart;
  final VoidCallback onCompare;
  final VoidCallback onReport;
  final VoidCallback onLayers;
  final VoidCallback onOperator;

  @override
  Widget build(BuildContext context) {
    final pal   = context.palette;
    final dark  = Theme.of(context).brightness == Brightness.dark;
    final route = session.route;
    final stats = route.stats[session.operatorFilter] ??
        route.stats['all']!;
    final lowSegs = route.segments
        .where((s) {
          final l = s.levelFor(session.operatorFilter);
          return l == 'none' || l == 'weak';
        })
        .toList();
    final lowMin   = lowSegs.fold<int>(0, (t, s) => t + s.min);
    final lowStart = lowSegs.isEmpty
        ? null
        : lowSegs.first.label.split(' – ').first;
    final heroColor =
        lowSegs.isEmpty ? pal.beacon : pal.moderate;

    return DraggableScrollableSheet(
      controller: sheetCtrl,
      initialChildSize: _kSnapHalf,
      minChildSize: _kSnapCollapsed,
      maxChildSize: _kSnapFull,
      snapSizes: const [_kSnapCollapsed, _kSnapHalf, _kSnapFull],
      snap: true,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: dark ? 0.45 : 0.16),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollCtrl,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag handle ───────────────────────────────
                    GestureDetector(
                      onTap: () {
                        final cur = sheetCtrl.size;
                        if (cur <= _kSnapCollapsed + 0.02) {
                          onSnapTo(_kSnapHalf);
                        } else if (cur <= _kSnapHalf + 0.02) {
                          onSnapTo(_kSnapFull);
                        } else {
                          onSnapTo(_kSnapCollapsed);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: pal.border,
                              borderRadius:
                                  BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Collapsed: headline row ───────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          18, 0, 18, 0),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${route.durationMin ~/ 60}h '
                            '${route.durationMin % 60}m',
                            style: TextStyle(
                              color: heroColor,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${route.distanceKm.toStringAsFixed(0)} km',
                              style: TextStyle(
                                color: pal.muted,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 2),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          18, 0, 18, 0),
                      child: Text(
                        '${route.name} · '
                        '${operatorLabel(session.operatorFilter)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: pal.muted, fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Signal bar (always visible) ───────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          18, 0, 18, 0),
                      child: SignalCoverageBar(
                          stats: stats,
                          height: 10,
                          showLabels: true),
                    ),

                    const SizedBox(height: 14),

                    // ── Low-signal warning pill ───────────────────
                    if (lowMin > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            18, 0, 18, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: pal.warningContainer,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  PhosphorIconsRegular.wifiSlash,
                                  size: 15,
                                  color: pal.onWarningContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lowStart != null
                                      ? '$lowMin min low/no signal from $lowStart'
                                      : '$lowMin min low/no signal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: pal.onWarningContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (lowMin > 0) const SizedBox(height: 14),

                    // ── Action buttons ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          18, 0, 18, 0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: FilledButton.icon(
                              onPressed: onStart,
                              icon: const Icon(
                                  PhosphorIconsRegular
                                      .navigationArrow,
                                  size: 17),
                              label: const Text('Start'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: OutlinedButton.icon(
                              onPressed: onCompare,
                              icon: const Icon(
                                  PhosphorIconsRegular
                                      .arrowsLeftRight,
                                  size: 15),
                              label: const Text('Compare'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            icon: Icon(
                                PhosphorIconsRegular.dotsThree,
                                color: pal.muted),
                            onSelected: (v) {
                              if (v == 'report') onReport();
                              if (v == 'offline') {
                                // demo notice
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'report',
                                child: Text('Pre-trip report'),
                              ),
                              PopupMenuItem(
                                value: 'offline',
                                child:
                                    Text('Offline availability'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Full-only content ─────────────────────────
                    // Thin divider that separates half from full
                    Divider(height: 1, color: pal.border),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // ── All-operators coverage ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Text(
                    'Coverage by network',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    const ops = [
                      'jio',
                      'airtel',
                      'vi',
                      'bsnl'
                    ];
                    final op    = ops[i];
                    final opStats =
                        route.stats[op] ?? route.stats['all']!;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          18, 10, 18, 0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                operatorLabel(op),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opStats['good'] ?? 0}% good',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pal.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SignalCoverageBar(
                              stats: opStats, height: 7),
                        ],
                      ),
                    );
                  },
                  childCount: 4,
                ),
              ),

              // ── Route segments ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
                  child: Text(
                    'Route segments',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final seg  = route.segments[i];
                    final level =
                        seg.levelFor(session.operatorFilter);
                    final isLow =
                        level == 'none' || level == 'weak';
                    return Column(
                      children: [
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isLow
                                  ? pal.warningContainer
                                  : pal.successContainer,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isLow
                                  ? PhosphorIconsRegular
                                      .wifiSlash
                                  : PhosphorIconsRegular.wifiHigh,
                              size: 17,
                              color: isLow
                                  ? pal.onWarningContainer
                                  : pal.onSuccessContainer,
                            ),
                          ),
                          title: Text(
                            seg.label,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${seg.km.toStringAsFixed(0)} km · '
                            '${formatDuration(seg.min)}',
                            style: TextStyle(
                                color: pal.muted, fontSize: 12),
                          ),
                          trailing: SignalChip(
                              level: level, compact: true),
                        ),
                        if (i < route.segments.length - 1)
                          Divider(
                            height: 1,
                            color: pal.border,
                            indent: 18,
                            endIndent: 18,
                          ),
                      ],
                    );
                  },
                  childCount: route.segments.length,
                ),
              ),

              // Bottom padding for nav bar clearance
              const SliverToBoxAdapter(
                  child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _categoryColor(String category, SignalPalette palette) =>
    switch (category) {
      'hospital'  => const Color(0xFFE7483B),
      'police'    => palette.route,
      'fuel'      => const Color(0xFFE58A00),
      'hotel'     => const Color(0xFF9A4DCE),
      'recovery'  => palette.good,
      'blackspot' => palette.moderate,
      _           => palette.text,
    };

Color _opColor(String op) => switch (op) {
      'jio'    => const Color(0xFF1F6BFF),
      'airtel' => const Color(0xFFE10600),
      'vi'     => const Color(0xFF7A3EAE),
      'bsnl'   => const Color(0xFFD6A100),
      _        => const Color(0xFF6BA8FF),
    };

class _DottedConnectorPainter extends CustomPainter {
  const _DottedConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF8FA39E);
    for (var y = 0.0; y < size.height; y += 5) {
      canvas.drawCircle(Offset(size.width / 2, y + 1), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedConnectorPainter _) => false;
}
