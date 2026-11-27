import 'dart:async';

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
import '../../theme/motion.dart';
import '../../widgets/hud.dart';
import '../../widgets/map_motion.dart';
import '../../widgets/session_gate.dart';
import '../../widgets/spring_sheet.dart';
import '../../widgets/staged_sheet.dart';
import 'map_sheets.dart';
import 'map_widgets.dart';

/// Explore = looking around (search pill + chips + "around you" sheet).
/// Directions = a route between two places is on screen.
enum MapMode { explore, directions }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialMode = MapMode.explore});

  final MapMode initialMode;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final _map = MapController();
  late final _camera = MapCameraAnimator(map: _map, vsync: this);
  final _sheet = SpringSheetController();
  final _routeHit = LayerHitNotifier<String>(null);

  /// 0 → 1 over the staged directions reveal: routes draw, then bubbles pop.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late MapMode _mode = widget.initialMode;
  bool _loadingRoutes = false;
  Timer? _loadingTimer;

  String? _category;
  bool _towers = true;
  bool _essentials = true;
  bool _blackspots = true;

  @override
  void initState() {
    super.initState();
    if (_mode == MapMode.directions) _reveal.value = 1;
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _camera.dispose();
    _reveal.dispose();
    _sheet.dispose();
    _routeHit.dispose();
    super.dispose();
  }

  // ── Mode changes (the staged reveal) ─────────────────────────────────────

  /// Directions: the sheet swaps to shimmering placeholders, the top pill
  /// becomes the from/to card, the camera glides out to fit the route, the
  /// routes draw themselves, and the time/signal bubbles pop in last.
  void _enterDirections(Session session) {
    final reduced = Motion.reduced(context);
    setState(() {
      _mode = MapMode.directions;
      _loadingRoutes = !reduced;
      _category = null;
    });
    _sheet.snapTo(SheetDetent.half);
    _loadingTimer?.cancel();
    _loadingTimer = Timer(Motion.skeletonHold, () {
      if (mounted) setState(() => _loadingRoutes = false);
    });
    if (reduced) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
    _fitRoutes(session);
  }

  void _exitDirections(Session session) {
    _loadingTimer?.cancel();
    setState(() {
      _mode = MapMode.explore;
      _loadingRoutes = false;
    });
    _reveal.value = 0;
    _sheet.snapTo(SheetDetent.half);
    _camera.moveTo(
      session.here,
      11.5,
      duration: Motion.of(context, Motion.recenter),
    );
  }

  void _fitRoutes(Session session) {
    final h = MediaQuery.sizeOf(context).height;
    final all = [for (final r in session.catalog.routes) ...r.points];
    _camera.fitBounds(
      LatLngBounds.fromPoints(all),
      padding: EdgeInsets.fromLTRB(40, 170, 56, h * 0.46 + 24),
      duration: Motion.of(context, Motion.camera),
    );
  }

  void _selectRoute(String id) {
    if (id == ref.read(sessionProvider)?.selectedRouteId) return;
    ref
        .read(sessionProvider.notifier)
        .update((s) => s.copyWith(selectedRouteId: id));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      builder: (context, session) {
        final directions = _mode == MapMode.directions;
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: _buildMap(context, session)),

              // Map buttons ride on top of the sheet and fade as it rises.
              _FloatingControls(
                sheet: _sheet,
                directions: directions,
                onLayers: () => _layers(context),
                onLocate: () => _camera.moveTo(
                  session.here,
                  13,
                  duration: Motion.of(context, Motion.recenter),
                ),
                onDirections: () => _enterDirections(session),
              ),

              SpringSheet(
                controller: _sheet,
                peekHeight: directions ? 96 : 72,
                halfFraction: 0.42,
                header: AnimatedBuilder(
                  animation: _sheet,
                  builder: (context, _) => AnimatedSwitcher(
                    duration: Motion.of(context, Motion.standard),
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.exit,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: directions
                        ? DirectionsHeader(
                            key: const ValueKey('dir'),
                            session: session,
                            loading: _loadingRoutes,
                            expansion: _sheet.expansion,
                            onCollapse: () => _sheet.snapTo(SheetDetent.half),
                            onOperator: (op) => ref
                                .read(sessionProvider.notifier)
                                .update((s) => s.copyWith(operatorFilter: op)),
                          )
                        : ExploreHeader(
                            key: const ValueKey('explore'),
                            session: session,
                            expansion: _sheet.expansion,
                            onCollapse: () => _sheet.snapTo(SheetDetent.half),
                          ),
                  ),
                ),
                builder: (context, scroll, physics) => AnimatedSwitcher(
                  duration: Motion.of(context, Motion.standard),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  child: directions
                      ? DirectionsBody(
                          key: const ValueKey('dir'),
                          session: session,
                          scroll: scroll,
                          physics: physics,
                          loading: _loadingRoutes,
                          onStart: () => _start(context, session),
                          onOffline: () => _offline(context),
                          onReport: () => context.push('/report'),
                          onCompare: () => context.push('/compare'),
                          onShare: () => _toast(
                            context,
                            'Route link copied (demo)',
                            PhosphorIconsRegular.shareNetwork,
                          ),
                          onSelectRoute: _selectRoute,
                        )
                      : ExploreBody(
                          key: const ValueKey('explore'),
                          session: session,
                          scroll: scroll,
                          physics: physics,
                          onDirections: () => _enterDirections(session),
                          onTripDetails: () => context.push('/trip/t1'),
                          onPlace: (p) => _placeSheet(context, p),
                          onTower: (t) => _towerSheet(context, t),
                          onReport: (r) => _reportSheet(context, r),
                          onSeeCommunity: () => context.go('/community'),
                        ),
                ),
              ),

              // Top chrome: search pill ↔ from/to card. Slides up and fades
              // out as the sheet goes full, so the sheet header becomes the
              // top bar.
              _TopChrome(
                sheet: _sheet,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: Motion.of(context, Motion.standard),
                      curve: Motion.enter,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.standard),
                        switchInCurve: Motion.enter,
                        switchOutCurve: Motion.exit,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.96, end: 1.0).animate(a),
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                        child: directions
                            ? Padding(
                                key: const ValueKey('fromto'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: FromToCard(
                                  origin: session.origin.name,
                                  destination: session.destination.name,
                                  onBack: () => _exitDirections(session),
                                  onOrigin: () =>
                                      _search(context, session, 'origin'),
                                  onDestination: () =>
                                      _search(context, session, 'destination'),
                                  onSwap: () => ref
                                      .read(sessionProvider.notifier)
                                      .update(
                                        (s) => s.copyWith(
                                          originId: s.destinationId,
                                          destinationId: s.originId,
                                        ),
                                      ),
                                ),
                              )
                            : Column(
                                key: const ValueKey('search'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: SearchPill(
                                      initial: session.userName.characters
                                          .first,
                                      onSearch: () => _search(
                                        context,
                                        session,
                                        'destination',
                                      ),
                                      onProfile: () =>
                                          context.go('/profile'),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  CategoryChips(
                                    selected: _category,
                                    onSelected: (c) => setState(() {
                                      _category = c;
                                      _essentials = true;
                                    }),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMap(BuildContext context, Session session) {
    final pal = context.palette;
    final directions = _mode == MapMode.directions;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: session.here,
        initialZoom: directions ? 8.4 : 11.5,
        onMapReady: () {
          if (directions) _fitRoutes(session);
        },
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _camera.isAnimating) _camera.stop();
        },
        onLongPress: (_, pt) => _droppedPin(context, session, pt),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.signalsafe.app',
          tileBuilder: Theme.of(context).brightness == Brightness.dark
              ? darkModeTileBuilder
              : _calmTileBuilder,
        ),
        if (session.overlayOn && _blackspots)
          PolygonLayer(
            polygons: [
              for (final spot in session.catalog.blackspots)
                Polygon(
                  points: spot.points,
                  color: pal.moderate.withValues(alpha: 0.12),
                  borderColor: pal.moderate.withValues(alpha: 0.45),
                  borderStrokeWidth: 1.2,
                ),
            ],
          ),
        if (directions)
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) => _routeLayer(context, session, pal),
          ),
        MarkerLayer(markers: _poiMarkers(context, session, pal)),
        if (directions)
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) =>
                MarkerLayer(markers: _routeMarkers(context, session, pal)),
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: session.here,
              width: 56,
              height: 56,
              child: Semantics(
                label: 'Your location',
                child: const _LocationPuck(),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  /// Slightly lighter, lower-contrast OSM tiles so the route and pins are
  /// what stands out (the "calm pastel map" look).
  static Widget _calmTileBuilder(
    BuildContext context,
    Widget tile,
    TileImage image,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.86, 0.06, 0.06, 0, 18, //
        0.05, 0.88, 0.05, 0, 18, //
        0.05, 0.06, 0.86, 0, 20, //
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }

  double get _drawT => const Interval(
    0.25,
    0.62,
    curve: Curves.easeInOut,
  ).transform(_reveal.value);

  Widget _routeLayer(BuildContext context, Session session, SignalPalette pal) {
    final t = _drawT;
    if (t <= 0) return const SizedBox.shrink();
    final route = session.route;
    final op = session.operatorFilter;
    final slices = splitByWeight(
      trimPolyline(route.points, 1), // full slices, trimmed below
      route.segments.map((s) => s.km).toList(),
    );
    final alternates = session.catalog.routes.where((r) => r.id != route.id);

    // Selected route drawn progressively: slices are trimmed so the whole
    // line grows from start to end.
    final totalSlices = slices.length;
    final selected = <Polyline<String>>[];
    for (var i = 0; i < totalSlices; i++) {
      final sliceStart = i / totalSlices;
      final sliceEnd = (i + 1) / totalSlices;
      if (t <= sliceStart) break;
      final local = ((t - sliceStart) / (sliceEnd - sliceStart)).clamp(0.0, 1.0);
      final pts = trimPolyline(slices[i], local);
      final low = _isLow(route.segments[i].levelFor(op));
      selected
        ..add(Polyline(points: pts, color: Colors.white, strokeWidth: 12))
        ..add(
          Polyline(
            points: pts,
            color: low ? pal.moderate : pal.route,
            strokeWidth: 7,
            pattern: low
                ? const StrokePattern.dotted(spacingFactor: 1.6)
                : const StrokePattern.solid(),
          ),
        );
    }

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.deferToChild,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final hit = _routeHit.value?.hitValues;
          if (hit != null && hit.isNotEmpty) _selectRoute(hit.first);
        },
        child: PolylineLayer<String>(
          hitNotifier: _routeHit,
          minimumHitbox: 18,
          polylines: [
            for (final r in alternates) ...[
              Polyline(
                points: trimPolyline(r.points, t),
                color: Colors.white,
                strokeWidth: 9,
                hitValue: r.id,
              ),
              Polyline(
                points: trimPolyline(r.points, t),
                color: Color.alphaBlend(
                  pal.route.withValues(alpha: 0.4),
                  pal.surface,
                ),
                strokeWidth: 5.5,
                hitValue: r.id,
              ),
            ],
            ...selected,
          ],
        ),
      ),
    );
  }

  List<Marker> _routeMarkers(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
    final markers = <Marker>[];
    final route = session.route;
    final op = session.operatorFilter;

    if (_drawT >= 1) {
      markers.add(_destinationPin(context, session, pal));
    }

    // Time/signal bubbles pop in last, one after another.
    final routes = session.catalog.routes;
    const anchors = [0.42, 0.6, 0.3];
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      final start = (900 + 90 * i) / 1500;
      final p = Interval(
        start.clamp(0.0, 1.0),
        (start + 0.2).clamp(0.0, 1.0),
        curve: Motion.enter,
      ).transform(_reveal.value);
      if (p <= 0) continue;
      final best = r.id == session.rankedRoutes().first.id;
      markers.add(
        Marker(
          point: pointAlong(r.points, anchors[i % anchors.length]),
          width: 140,
          height: 40,
          child: Opacity(
            opacity: p,
            child: Transform.scale(
              scale: 0.82 + 0.18 * p,
              child: Center(
                child: RouteBubble(
                  duration: formatDuration(r.durationMin),
                  score: networkScore(r, op),
                  selected: r.id == route.id,
                  best: best,
                  onTap: () => _selectRoute(r.id),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Callout where the selected route first loses signal.
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    final gap = route.segments.indexWhere((s) => _isLow(s.levelFor(op)));
    final cp = const Interval(0.85, 1, curve: Motion.enter).transform(
      _reveal.value,
    );
    if (gap >= 0 && slices[gap].isNotEmpty && cp > 0) {
      final seg = route.segments[gap];
      final none = seg.levelFor(op) == 'none';
      markers.add(
        Marker(
          point: slices[gap][slices[gap].length ~/ 2],
          width: 150,
          height: 34,
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: cp,
            child: Semantics(
              label: '${seg.min} min ${none ? 'no-signal' : 'weak-signal'} section',
              excludeSemantics: true,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pal.warningContainer,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: softShadow(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.wifiSlash,
                        size: 13,
                        color: pal.onWarningContainer,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${seg.min} min ${none ? 'no signal' : 'weak'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pal.onWarningContainer,
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
    return markers;
  }

  bool _isLow(String level) => level == 'none' || level == 'weak';

  List<Marker> _poiMarkers(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
    final markers = <Marker>[];
    final directions = _mode == MapMode.directions;

    if (_towers) {
      for (final tower in session.catalog.towers) {
        if (session.operatorFilter != 'all' &&
            tower.operator != session.operatorFilter) {
          continue;
        }
        markers.add(
          _pin(
            tower.point,
            operatorColor(tower.operator),
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
        if (place.id == session.originId ||
            (directions && place.id == session.destinationId)) {
          continue;
        }
        if (_category != null && place.category != _category) continue;
        if (_category == null &&
            !const {
              'recovery',
              'hospital',
              'police',
              'fuel',
            }.contains(place.category)) {
          continue;
        }
        markers.add(
          _pin(
            place.point,
            categoryAccent(place.category, pal),
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
            width: 48,
            height: 48,
            child: Semantics(
              button: true,
              label:
                  '${_levelWord(report.level)} signal report, '
                  '${operatorLabel(report.operator)}, '
                  '${agoLabel(report.minutesAgo)}',
              onTap: () => _reportSheet(context, report),
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _reportSheet(context, report),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: pal.level(report.level),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: softShadow(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  String _levelWord(String level) => switch (level) {
    'good' => 'Good',
    'moderate' => 'Moderate',
    'weak' => 'Weak',
    _ => 'No',
  };

  Marker _destinationPin(
    BuildContext context,
    Session session,
    SignalPalette pal,
  ) {
    return Marker(
      point: session.destination.point,
      width: 48,
      height: 56,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        label: 'Destination, ${session.destination.name}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _placeSheet(context, session.destination),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Icon(
              PhosphorIconsFill.mapPin,
              size: 40,
              color: pal.destination,
            ),
          ),
        ),
      ).animate().scale(
        begin: const Offset(0.4, 0.4),
        alignment: Alignment.bottomCenter,
        duration: 280.ms,
        curve: Motion.enter,
      ),
    );
  }

  /// Small glyph pin with a 48dp tap target.
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
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: softShadow(context),
              ),
              child: Icon(icon, size: 13, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _search(
    BuildContext context,
    Session session,
    String mode,
  ) async {
    final picked = await context.push<String>('/search?mode=$mode');
    if (!mounted || picked == null) return;
    final s = ref.read(sessionProvider);
    if (s == null) return;
    // Picking a place (or changing an end of the trip) runs the staged
    // directions reveal for the new trip.
    _enterDirections(s);
  }

  void _start(BuildContext context, Session session) {
    ref
        .read(sessionProvider.notifier)
        .update(
          (s) => s.copyWith(selectedRouteId: session.route.id, navProgress: 0.08),
        );
    context.push('/navigate');
  }

  void _offline(BuildContext context) {
    ref.read(sessionProvider.notifier).update((s) {
      final trips = [
        for (final t in s.trips)
          t.routeId == s.selectedRouteId && t.kind == 'saved'
              ? t.copyWith(offlinePrepared: true)
              : t,
      ];
      return s.copyWith(trips: trips);
    });
    _toast(
      context,
      'Offline plan saved (demo). Map tiles still need a connection.',
      PhosphorIconsRegular.downloadSimple,
    );
  }

  void _toast(BuildContext context, String text, IconData icon) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  // ── Modal sheets: scrim first, then the sheet ────────────────────────────

  Future<void> _layers(BuildContext context) {
    return showStagedSheet<void>(
      context: context,
      title: 'Map details',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final session = ref.watch(sessionProvider);
          if (session == null) return const SizedBox.shrink();
          void toggle(void Function() change) {
            change();
            setSheet(() {});
            setState(() {});
          }

          final tiles = [
            (
              'Signal overlay',
              PhosphorIconsRegular.wifiHigh,
              session.overlayOn,
              () => ref
                  .read(sessionProvider.notifier)
                  .update((s) => s.copyWith(overlayOn: !s.overlayOn)),
            ),
            (
              'Community',
              PhosphorIconsRegular.usersThree,
              session.communityLayerOn,
              () => ref
                  .read(sessionProvider.notifier)
                  .update(
                    (s) => s.copyWith(communityLayerOn: !s.communityLayerOn),
                  ),
            ),
            (
              'Towers',
              PhosphorIconsRegular.broadcast,
              _towers,
              () => _towers = !_towers,
            ),
            (
              'Essentials',
              PhosphorIconsRegular.firstAid,
              _essentials,
              () => _essentials = !_essentials,
            ),
            (
              'Blackspots',
              PhosphorIconsRegular.warning,
              _blackspots,
              () => _blackspots = !_blackspots,
            ),
          ];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final t in tiles)
                      _LayerTile(
                        label: t.$1,
                        icon: t.$2,
                        on: t.$3,
                        onTap: () => toggle(t.$4),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Network',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final op in NetworkTabs.ops)
                      ChoiceChip(
                        label: Text(operatorLabel(op)),
                        selected: session.operatorFilter == op,
                        showCheckmark: true,
                        shape: const StadiumBorder(),
                        onSelected: (_) => toggle(
                          () => ref
                              .read(sessionProvider.notifier)
                              .update((s) => s.copyWith(operatorFilter: op)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _placeSheet(BuildContext context, Place place) {
    final pal = context.palette;
    final session = ref.read(sessionProvider)!;
    final km = distance(session.here, place.point) / 1000;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showStagedSheet<void>(
      context: context,
      title: place.name,
      subtitle: place.subtitle,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: categoryTint(place.category, dark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          categoryIcon(place.category),
          color: categoryAccent(place.category, pal),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MetaLine([
                _categoryWord(place.category),
                '${km.toStringAsFixed(km < 10 ? 1 : 0)} km from you',
                'Estimated',
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
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
                      _enterDirections(ref.read(sessionProvider)!);
                    },
                    icon: const Icon(
                      PhosphorIconsFill.arrowBendUpRight,
                      size: 18,
                    ),
                    label: const Text('Directions'),
                  ),
                  const SizedBox(width: 8),
                  TonalPill(
                    icon: PhosphorIconsRegular.navigationArrow,
                    label: 'Set as start',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(sessionProvider.notifier)
                          .update((s) => s.copyWith(originId: place.id));
                    },
                  ),
                  const SizedBox(width: 8),
                  TonalPill(
                    icon: PhosphorIconsRegular.crosshair,
                    label: 'Show on map',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _camera.moveTo(place.point, 13.5);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryWord(String c) => switch (c) {
    'hospital' => 'Hospital',
    'police' => 'Police',
    'fuel' => 'Fuel',
    'hotel' => 'Stay',
    'restaurant' => 'Food',
    'atm' => 'ATM',
    'recovery' => 'Signal recovery point',
    'blackspot' => 'Weak-signal area',
    'destination' => 'Destination',
    _ => 'Place',
  };

  void _towerSheet(BuildContext context, Tower tower) {
    final pal = context.palette;
    final c = operatorColor(tower.operator);
    showStagedSheet<void>(
      context: context,
      title: tower.name,
      subtitle: '${operatorLabel(tower.operator)} · ${tower.tech}',
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(PhosphorIconsFill.broadcast, color: c),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tower.detail, style: TextStyle(color: pal.text, height: 1.45)),
            const SizedBox(height: 10),
            MetaLine([
              switch (tower.source) {
                'measured' => 'Measured',
                'metadata' => 'Tower metadata',
                'community' => 'Community',
                _ => 'Estimated',
              },
              '${tower.point.latitude.toStringAsFixed(4)}, '
                  '${tower.point.longitude.toStringAsFixed(4)}',
            ]),
          ],
        ),
      ),
    );
  }

  void _reportSheet(BuildContext context, SignalReport report) {
    final pal = context.palette;
    showStagedSheet<void>(
      context: context,
      title: switch (report.level) {
        'good' => 'Good signal here',
        'moderate' => 'Moderate signal',
        'weak' => 'Weak signal here',
        _ => 'No signal here',
      },
      subtitle:
          '${operatorLabel(report.operator)} · ${report.tech} · ${agoLabel(report.minutesAgo)}',
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: pal.levelContainer(report.level),
          shape: BoxShape.circle,
        ),
        child: Center(child: SignalBars(level: report.level)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.comment.isNotEmpty)
              Text(report.comment, style: TextStyle(color: pal.text, height: 1.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                const SourceTag(source: 'community'),
                const Spacer(),
                Text(
                  '${(report.agreement * 100).round()}% agree',
                  style: dataStyle(context, size: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _droppedPin(BuildContext context, Session session, LatLng point) {
    Place? nearest;
    var best = double.infinity;
    for (final place in session.catalog.places) {
      final m = distance(point, place.point);
      if (m < best) {
        best = m;
        nearest = place;
      }
    }
    if (nearest != null) _placeSheet(context, nearest);
  }
}

// ---------------------------------------------------------------------------
// Chrome that reacts to the sheet
// ---------------------------------------------------------------------------

class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.sheet, required this.child});

  final SpringSheetController sheet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AnimatedBuilder(
              animation: sheet,
              builder: (context, child) {
                // Starts leaving once the sheet passes ~40% of the way from
                // half to full, gone before the sheet reaches the top.
                final t = ((sheet.expansion - 0.35) / 0.5).clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: t > 0.5,
                  child: Opacity(
                    opacity: 1 - t,
                    child: Transform.translate(
                      offset: Offset(0, -36 * t),
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.sheet,
    required this.directions,
    required this.onLayers,
    required this.onLocate,
    required this.onDirections,
  });

  final SpringSheetController sheet;
  final bool directions;
  final VoidCallback onLayers;
  final VoidCallback onLocate;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Layers: top right, under the search chrome.
        Positioned(
          right: 12,
          top: top + (directions ? 120 : 124),
          child: AnimatedBuilder(
            animation: sheet,
            builder: (context, child) => Opacity(
              opacity: (1 - sheet.expansion * 2).clamp(0.0, 1.0),
              child: child,
            ),
            child: RoundIconButton(
              icon: PhosphorIconsRegular.stack,
              tooltip: 'Map layers',
              size: 44,
              onTap: onLayers,
            ),
          ),
        ),
        // Locate + the one filled button sit just above the sheet and ride
        // with it, fading out as it rises past half.
        AnimatedBuilder(
          animation: sheet,
          builder: (context, child) {
            final fade = (1 - sheet.expansion * 3).clamp(0.0, 1.0);
            return Positioned(
              right: 12,
              bottom: sheet.height + 12,
              child: IgnorePointer(
                ignoring: fade < 0.3,
                child: Opacity(opacity: fade, child: child),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RoundIconButton(
                icon: PhosphorIconsRegular.crosshair,
                tooltip: 'My location',
                size: 44,
                onTap: onLocate,
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.standard),
                curve: Motion.enter,
                child: directions
                    ? const SizedBox(width: 0)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: PrimaryMapFab(
                          icon: PhosphorIconsFill.arrowBendUpRight,
                          tooltip: 'Directions',
                          onTap: onDirections,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      toggled: on,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.enter,
          decoration: BoxDecoration(
            color: on ? pal.secondaryContainer : pal.elevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? pal.beacon : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: on ? pal.beacon : pal.muted, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? pal.text : pal.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You are here": a teal dot with a slow breathing halo.
class _LocationPuck extends StatelessWidget {
  const _LocationPuck();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    Widget halo = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: pal.beacon.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
    );
    if (!Motion.reduced(context)) {
      halo = halo
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.6, 0.6),
            end: const Offset(1, 1),
            duration: 1600.ms,
            curve: Curves.easeInOut,
          );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        halo,
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: pal.beacon,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: softShadow(context),
          ),
        ),
      ],
    );
  }
}
