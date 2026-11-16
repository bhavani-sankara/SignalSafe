import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import '../../widgets/frosted.dart';
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
  final _sheet = DraggableScrollableController();
  final _extent = ValueNotifier<double>(0);
  double _bottomInset = 0;

  @override
  void dispose() {
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

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
          body: LayoutBuilder(
            builder: (context, box) {
              final height = box.maxHeight;
              _bottomInset = MediaQuery.paddingOf(context).bottom;
              if (_extent.value == 0) _extent.value = _peekSize(height);
              return Stack(
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
                  // Floating search + chips; chips fade as the sheet takes over.
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<double>(
                                valueListenable: _extent,
                                builder: (context, e, child) {
                                  final t = ((e - 0.8) / 0.1).clamp(0.0, 1.0);
                                  return IgnorePointer(
                                    ignoring: t > 0.5,
                                    child: Opacity(
                                      opacity: 1 - t,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _searchBar(context, session),
                              ),
                              const SizedBox(height: 10),
                              ValueListenableBuilder<double>(
                                valueListenable: _extent,
                                builder: (context, e, child) {
                                  final t = ((e - _halfSize) / 0.2).clamp(
                                    0.0,
                                    1.0,
                                  );
                                  return IgnorePointer(
                                    ignoring: t > 0.5,
                                    child: Opacity(
                                      opacity: 1 - t,
                                      child: Transform.translate(
                                        offset: Offset(0, -12 * t),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: _chips(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Map controls, top-right under the chips.
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 172, 12, 0),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _extent,
                          builder: (context, e, child) {
                            final t = ((e - (_halfSize + 0.04)) / 0.12).clamp(
                              0.0,
                              1.0,
                            );
                            return IgnorePointer(
                              ignoring: t > 0.5,
                              child: Opacity(opacity: 1 - t, child: child),
                            );
                          },
                          child: Frosted(
                            borderRadius: BorderRadius.circular(16),
                            lift: 0.7,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MapControl(
                                  icon: PhosphorIconsRegular.stack,
                                  tooltip: 'Map layers',
                                  onTap: () => _layers(context, session),
                                ),
                                _MapControl(
                                  icon: session.overlayOn
                                      ? PhosphorIconsFill.wifiHigh
                                      : PhosphorIconsRegular.wifiHigh,
                                  tooltip: session.overlayOn
                                      ? 'Hide signal overlay'
                                      : 'Show signal overlay',
                                  selected: session.overlayOn,
                                  onTap: () => ref
                                      .read(sessionProvider.notifier)
                                      .update(
                                        (s) =>
                                            s.copyWith(overlayOn: !s.overlayOn),
                                      ),
                                ),
                                _MapControl(
                                  icon: PhosphorIconsRegular.broadcast,
                                  tooltip: 'Network operator',
                                  onTap: () => _operators(context, session),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // My-location button rides on top of the sheet, like a
                  // floating action that follows your thumb.
                  ValueListenableBuilder<double>(
                    valueListenable: _extent,
                    builder: (context, e, child) {
                      final fade = ((e - (_halfSize + 0.03)) / 0.08).clamp(
                        0.0,
                        1.0,
                      );
                      return Positioned(
                        right: 16,
                        bottom: e * height + 14,
                        child: IgnorePointer(
                          ignoring: fade > 0.5,
                          child: Opacity(
                            opacity: 1 - fade,
                            child: Transform.scale(
                              scale: 1 - 0.2 * fade,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Tooltip(
                      message: 'My location',
                      child: PressScale(
                        onTap: () => _map.move(session.here, 13),
                        child: Frosted(
                          borderRadius: BorderRadius.circular(18),
                          opacity: 0.95,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(
                              PhosphorIconsFill.crosshair,
                              color: pal.beacon,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _journeySheet(context, session, height),
                ],
              );
            },
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
      for (var i = 0; i < slices.length; i++) ...[
        Polyline(points: slices[i], color: Colors.white, strokeWidth: 11),
        Polyline(
          points: slices[i],
          color:
              _isLowSignal(route.segments[i].levelFor(session.operatorFilter))
              ? pal.moderate
              : pal.route,
          strokeWidth: 7,
          pattern:
              _isLowSignal(route.segments[i].levelFor(session.operatorFilter))
              ? const StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
      ],
    ];
  }

  bool _isLowSignal(String level) => level == 'none' || level == 'weak';

  List<Marker> _markers(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
    final route = session.route;
    final slices = splitByWeight(
      route.points,
      route.segments.map((segment) => segment.km).toList(),
    );
    final markers = <Marker>[
      _pin(
        session.here,
        pal.beacon,
        PhosphorIconsFill.navigationArrow,
        semanticLabel: 'Current location, ${session.origin.name}',
        onTap: () => _placeSheet(context, session.origin),
      ),
      _destinationPin(context, session, pal),
    ];
    final firstGap = route.segments.indexWhere(
      (segment) => _isLowSignal(segment.levelFor(session.operatorFilter)),
    );
    if (firstGap >= 0 && slices[firstGap].isNotEmpty) {
      final segment = route.segments[firstGap];
      final noSignal = segment.levelFor(session.operatorFilter) == 'none';
      markers.add(
        Marker(
          point: slices[firstGap][slices[firstGap].length ~/ 2],
          width: 148,
          height: 40,
          alignment: Alignment.centerLeft,
          child: Semantics(
            label:
                '${segment.min} minute ${noSignal ? 'no-signal' : 'weak-signal'} section',
            child: Material(
              color: pal.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.wifiSlash,
                      size: 16,
                      color: pal.moderate,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${segment.min} min ${noSignal ? 'no signal' : 'weak signal'}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
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
            place.category == 'hospital'
                ? pal.sos
                : _categoryColor(place.category, pal),
            place.category == 'hospital'
                ? PhosphorIconsRegular.plus
                : categoryIcon(place.category),
            semanticLabel: place.name,
            onTap: () => _placeSheet(context, place),
            iconColor: place.category == 'hospital'
                ? Colors.white
                : pal.onPrimaryContainer,
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

  Marker _destinationPin(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
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
            child: Icon(
              PhosphorIconsFill.mapPin,
              size: 42,
              color: pal.destination,
            ),
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
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, size: 15, color: iconColor ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context, Session session) {
    final pal = context.palette;
    return Frosted(
      borderRadius: BorderRadius.circular(28),
      lift: 1.1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const Positioned(
                    left: 10,
                    top: 30,
                    bottom: 30,
                    child: CustomPaint(
                      painter: _DottedConnectorPainter(),
                      size: Size(2, 36),
                    ),
                  ),
                  Column(
                    children: [
                      _routeStop(
                        context,
                        icon: PhosphorIconsRegular.navigationArrow,
                        color: pal.beacon,
                        name: session.origin.name,
                        onTap: () => context.push('/search?mode=origin'),
                      ),
                      _routeStop(
                        context,
                        icon: PhosphorIconsFill.mapPin,
                        color: pal.destination,
                        name: session.destination.name,
                        onTap: () => context.push('/search?mode=destination'),
                      ),
                    ],
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
          height: 48,
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
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = _category == item.$1;
          return _CategoryPill(
            icon: categoryIcon(item.$1),
            label: item.$2,
            color: item.$3,
            selected: selected,
            onTap: () => setState(() {
              _category = selected ? null : item.$1;
              _essentials = true;
            }),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Journey sheet: a draggable, snapping sheet (peek / half / full).
  // ---------------------------------------------------------------------

  static const double _peekPx = 196;
  static const double _halfSize = 0.52;
  static const double _fullSize = 1.0;

  double _peekSize(double height) => ((_peekPx + _bottomInset) / height)
      .clamp(0.12, _halfSize - 0.05)
      .toDouble();

  void _snapTo(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(size, duration: Motion.emphasized, curve: Motion.enter);
  }

  void _toggleSheet(double height) {
    final peek = _peekSize(height);
    final current = _sheet.isAttached ? _sheet.size : peek;
    _snapTo(current < (peek + _halfSize) / 2 ? _halfSize : peek);
  }

  Widget _journeySheet(BuildContext context, Session session, double height) {
    final peek = _peekSize(height);
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        _extent.value = n.extent;
        return false;
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: peek,
          minChildSize: peek,
          maxChildSize: _fullSize,
          snap: true,
          snapSizes: [peek, _halfSize],
          snapAnimationDuration: Motion.standard,
          builder: (context, scroll) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Frosted(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  lift: 1.4,
                  opacity: Theme.of(context).brightness == Brightness.dark
                      ? 0.88
                      : 0.92,
                  child: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // Clear the status bar once the sheet is fully open.
                            ValueListenableBuilder<double>(
                              valueListenable: _extent,
                              builder: (context, e, _) => SizedBox(
                                height:
                                    MediaQuery.paddingOf(context).top *
                                    ((e - 0.9) / 0.1).clamp(0.0, 1.0),
                              ),
                            ),
                            _sheetHeader(context, session, height),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _sheetActions(context, session),
                      ),
                      SliverToBoxAdapter(child: _sheetDivider(context)),
                      ..._sheetDetails(context, session),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 32 + _bottomInset),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sheetDivider(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(
      height: 1,
      thickness: 1,
      color: context.palette.border.withValues(alpha: 0.5),
    ),
  );

  Widget _sheetHeader(BuildContext context, Session session, double height) {
    final pal = context.palette;
    final route = session.route;
    final stats = route.stats[session.operatorFilter] ?? route.stats['all']!;
    final low = route.segments
        .where((s) => _isLowSignal(s.levelFor(session.operatorFilter)))
        .toList();
    final lowMin = low.fold<int>(0, (t, s) => t + s.min);
    final heroColor = low.isEmpty ? pal.beacon : pal.text;
    return Semantics(
      button: true,
      label: 'Journey details. Tap to expand or collapse.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSheet(height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: Motion.standard,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey('${route.id}-${session.operatorFilter}'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formatDuration(route.durationMin),
                                style: TextStyle(
                                  color: heroColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${route.distanceKm.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'via ${route.via} · ${operatorLabel(session.operatorFilter)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _ScorePill(score: route.connectivityScore),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CoverageStrip(stats: stats, height: 6),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    low.isEmpty
                        ? PhosphorIconsRegular.wifiHigh
                        : PhosphorIconsRegular.wifiSlash,
                    size: 15,
                    color: low.isEmpty ? pal.good : pal.weak,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      low.isEmpty
                          ? 'Connected the whole way'
                          : '$lowMin min with weak or no signal · from ${low.first.label.split(' – ').first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: low.isEmpty ? pal.good : pal.weak,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetActions(BuildContext context, Session session) {
    final route = session.route;
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        children: [
          FilledButton.icon(
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
            icon: const Icon(PhosphorIconsFill.navigationArrow, size: 18),
            label: const Text('Start'),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: PhosphorIconsRegular.downloadSimple,
            label: 'Offline',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Offline map downloads are not available in this demo.',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: PhosphorIconsRegular.clipboardText,
            label: 'Pre-trip report',
            onTap: () => context.push('/report'),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: PhosphorIconsRegular.arrowsLeftRight,
            label: 'Compare routes',
            onTap: () => context.push('/compare'),
          ),
          const SizedBox(width: 8),
          _ActionPill(
            icon: PhosphorIconsRegular.broadcast,
            label: operatorLabel(session.operatorFilter),
            onTap: () => _operators(context, session),
          ),
        ],
      ),
    );
  }

  List<Widget> _sheetDetails(BuildContext context, Session session) {
    final pal = context.palette;
    final route = session.route;
    final others = session
        .rankedRoutes()
        .where((r) => r.id != route.id)
        .toList();
    final essentials = session.catalog.places
        .where(
          (p) => const {
            'hospital',
            'police',
            'fuel',
            'recovery',
          }.contains(p.category),
        )
        .toList();
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String text, {String? sub}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: pal.text,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: pal.muted, fontSize: 12.5)),
          ],
        ],
      ),
    );

    return [
      SliverToBoxAdapter(
        child: heading(
          'Signal along the way',
          sub: 'Estimated for ${operatorLabel(session.operatorFilter)}',
        ),
      ),
      SliverList.builder(
        itemCount: route.segments.length,
        itemBuilder: (context, i) => SegmentRow(
          segment: route.segments[i],
          level: route.segments[i].levelFor(session.operatorFilter),
          first: i == 0,
          last: i == route.segments.length - 1,
        ),
      ),
      if (others.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: heading('Other routes', sub: 'Tap a route to switch'),
        ),
        SliverList.builder(
          itemCount: others.length,
          itemBuilder: (context, i) {
            final r = others[i];
            final stats = r.stats[session.operatorFilter] ?? r.stats['all']!;
            final delta = r.durationMin - route.durationMin;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PressScale(
                onTap: () {
                  ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(selectedRouteId: r.id));
                  _map.fitCamera(
                    CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(r.points),
                      padding: const EdgeInsets.fromLTRB(36, 170, 36, 260),
                    ),
                  );
                  final h = MediaQuery.sizeOf(context).height;
                  _snapTo(_peekSize(h));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pal.elevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pal.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            formatDuration(r.durationMin),
                            style: TextStyle(
                              color: pal.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'via ${r.via} · ${r.distanceKm.toStringAsFixed(0)} km',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pal.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Text(
                            delta == 0
                                ? 'Same time'
                                : delta > 0
                                ? '+${formatDuration(delta)}'
                                : '−${formatDuration(-delta)}',
                            style: TextStyle(
                              color: delta > 0 ? pal.muted : pal.good,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CoverageStrip(stats: stats, height: 5),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
      SliverToBoxAdapter(
        child: heading(
          'Help along the route',
          sub: 'Hospitals, police, fuel and signal recovery points',
        ),
      ),
      SliverList.builder(
        itemCount: essentials.length,
        itemBuilder: (context, i) {
          final p = essentials[i];
          final color = p.category == 'hospital'
              ? pal.sos
              : _categoryColor(p.category, pal);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIcon(p.category), size: 20, color: color),
            ),
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: pal.text, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              p.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: pal.muted, fontSize: 12.5),
            ),
            trailing: Icon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: pal.muted,
            ),
            onTap: () {
              _map.move(p.point, 13);
              _placeSheet(context, p);
            },
          );
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'Signal levels are estimates from tower metadata and community reports. '
            'Map downloads, live-location sharing and automatic SOS delivery are not available in this demo.',
            style: TextStyle(color: pal.muted, fontSize: 12, height: 1.4),
          ),
        ),
      ),
    ];
  }

  void _fit(Session session) {
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(session.route.points),
        padding: const EdgeInsets.fromLTRB(36, 170, 36, 240),
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

class _DottedConnectorPainter extends CustomPainter {
  const _DottedConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6F7977);
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawCircle(Offset(size.width / 2, y + 1), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedConnectorPainter oldDelegate) => false;
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final level = score >= 75
        ? 'good'
        : score >= 55
        ? 'moderate'
        : 'weak';
    return Semantics(
      label: 'Connectivity score $score out of 100',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: pal.levelContainer(level),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: pal.onLevelContainer(level),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.1,
                ),
              ),
              Text(
                'signal',
                style: TextStyle(
                  color: pal.onLevelContainer(level),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.beacon,
        backgroundColor: pal.surface.withValues(alpha: 0.6),
        side: BorderSide(color: pal.border),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressScale(
        onTap: onTap,
        child: Frosted(
          borderRadius: BorderRadius.circular(20),
          tint: selected ? pal.primaryContainer : null,
          opacity: selected ? 0.96 : null,
          lift: 0.5,
          child: AnimatedPadding(
            duration: Motion.quick,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: Motion.quick,
                  child: Icon(
                    selected ? PhosphorIconsBold.check : icon,
                    key: ValueKey(selected),
                    size: 17,
                    color: selected ? pal.onPrimaryContainer : color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? pal.onPrimaryContainer : pal.text,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedSwitcher(
              duration: Motion.quick,
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 22,
                color: selected ? pal.beacon : pal.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
