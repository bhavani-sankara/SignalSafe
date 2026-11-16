import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/frosted.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  Timer? _timer;
  final _tts = FlutterTts();
  final _map = MapController();
  String? _spoken;
  bool _playing = false;
  bool _expanded = false;
  double _cameraProgress = -1;

  static const _turns = [
    'Head south on the Outer Ring Road',
    'Continue toward Kalwakurthy',
    'Stay on NH 765 through Achampet',
    'Mannanur check post ahead',
    'Forest stretch. Signal will drop',
    'Hairpins toward Dornala',
    'Arrive in Srisailam',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play(bool on) {
    _timer?.cancel();
    _playing = on;
    if (!on) return;
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final session = ref.read(sessionProvider);
      if (session == null) return;
      final next = (session.navProgress + 0.02).clamp(0.0, 1.0);
      ref
          .read(sessionProvider.notifier)
          .update((s) => s.copyWith(navProgress: next, navActive: true));
      if (next >= 1) _play(false);
      _maybeSpeak();
    });
  }

  Future<void> _maybeSpeak() async {
    final session = ref.read(sessionProvider);
    if (session == null || !session.voiceOn) return;
    final line =
        _turns[segmentIndex(
          session.route,
          session.navProgress,
        ).clamp(0, _turns.length - 1)];
    if (line == _spoken) return;
    _spoken = line;
    try {
      await _tts.stop();
      await _tts.speak(line);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        final here = pointAlong(session.route.points, session.navProgress);
        final level = session.currentSegmentLevel();
        final gap = nextGap(
          session.route,
          session.operatorFilter,
          session.navProgress,
        );
        final recovery = nextRecovery(
          session.catalog.places,
          here,
          session.destination.point,
        );
        final remainingMin =
            (session.route.durationMin * (1 - session.navProgress)).round();
        final remainKm = session.route.distanceKm * (1 - session.navProgress);
        final eta = TimeOfDay.fromDateTime(
          DateTime.now().add(Duration(minutes: remainingMin)),
        );
        final turnIndex = segmentIndex(
          session.route,
          session.navProgress,
        ).clamp(0, _turns.length - 1);
        final turn = _turns[turnIndex];
        final nextTurn = turnIndex + 1 < _turns.length
            ? _turns[turnIndex + 1]
            : 'Arrive in ${session.destination.name}';
        final speed = session.simulateLoss
            ? 0
            : 42 + (session.navProgress * 28).round();
        _follow(here, session.navProgress);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final headerColor = dark ? pal.primaryContainer : pal.beacon;
        final headerForeground = dark ? pal.onPrimaryContainer : Colors.white;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: headerColor,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: pal.surface,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: pal.ink,
            body: Stack(
              children: [
                Positioned.fill(child: _navMap(session, pal, here)),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 620;
                          final veryCompact = constraints.maxHeight < 460;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _instructionBanner(
                                context,
                                session,
                                turn,
                                nextTurn,
                                headerColor,
                                headerForeground,
                                compact: compact,
                              ),
                              SizedBox(height: veryCompact ? 6 : 8),
                              if (veryCompact)
                                _compactStatusStrip(
                                  context,
                                  session,
                                  level,
                                  gap,
                                )
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _signalStatus(context, session, level),
                                ),
                                if (gap != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      0,
                                    ),
                                    child: _blackspotCard(
                                      context,
                                      session,
                                      gap,
                                      recovery,
                                      here,
                                      level,
                                      compact: compact,
                                    ),
                                  ),
                              ],
                              Expanded(
                                child: _mapActions(
                                  context,
                                  session,
                                  here,
                                  speed,
                                  horizontalControls: veryCompact,
                                ),
                              ),
                              _bottomSheet(
                                context,
                                session,
                                level,
                                gap,
                                recovery,
                                here,
                                remainKm,
                                remainingMin,
                                eta,
                                compact: compact,
                                veryCompact: veryCompact,
                              ),
                            ],
                          );
                        },
                      ),
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

  Widget _instructionBanner(
    BuildContext context,
    Session session,
    String turn,
    String nextTurn,
    Color background,
    Color foreground, {
    required bool compact,
  }) {
    return Material(
      color: background,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, compact ? 8 : 12, 18, 12),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsFill.arrowUp,
                  size: compact ? 44 : 52,
                  color: foreground,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.route.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        turn,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: compact ? 19 : 23,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Toward ${session.destination.name}',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.86),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: foreground.withValues(alpha: 0.13),
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: compact ? 7 : 9,
            ),
            child: Row(
              children: [
                Text(
                  'Then',
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  PhosphorIconsRegular.arrowBendRightUp,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextTurn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalStatus(BuildContext context, Session session, String level) {
    return Frosted(
      borderRadius: BorderRadius.circular(99),
      lift: 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SignalBars(level: level),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${_levelLabel(level)} · ${operatorLabel(session.operatorFilter)} · Estimated',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactStatusStrip(
    BuildContext context,
    Session session,
    String level,
    RouteSegment? gap,
  ) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: pal.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: pal.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SignalBars(level: level),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_levelLabel(level)} · ${operatorLabel(session.operatorFilter)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (gap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  PhosphorIconsRegular.wifiSlash,
                  size: 18,
                  color: pal.moderate,
                ),
                const SizedBox(width: 6),
                Text(
                  '${gap.km.toStringAsFixed(0)} km · ${formatDuration(gap.min)}',
                  style: TextStyle(
                    color: pal.onWarningContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _blackspotCard(
    BuildContext context,
    Session session,
    RouteSegment gap,
    Place? recovery,
    LatLng here,
    String level, {
    required bool compact,
  }) {
    final pal = context.palette;
    final noSignal = gap.levelFor(session.operatorFilter) == 'none';
    return Frosted(
      borderRadius: BorderRadius.circular(22),
      lift: 0.7,
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 36 : 44,
                  height: compact ? 36 : 44,
                  decoration: BoxDecoration(
                    color: pal.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.wifiSlash,
                    color: pal.onWarningContainer,
                    size: compact ? 18 : 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noSignal ? 'Blackspot ahead' : 'Weak signal ahead',
                        style: TextStyle(
                          color: pal.onWarningContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        gap.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${gap.km.toStringAsFixed(0)} km · about ${formatDuration(gap.min)} ${noSignal ? 'without signal' : 'with weak signal'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 12,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RouteCoveragePainter(
                    segments: session.route.segments,
                    operator: session.operatorFilter,
                    progress: session.navProgress,
                    palette: pal,
                  ),
                ),
              ),
              if (recovery != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: pal.border),
                ),
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.wifiHigh,
                      color: pal.beacon,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${recovery.name} · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pal.beacon,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            recovery.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pal.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (session.simulateLoss || level == 'none') ...[
              const SizedBox(height: 8),
              Text(
                'No usable signal here. SOS remains local in this demo.',
                style: TextStyle(color: pal.sos, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mapActions(
    BuildContext context,
    Session session,
    LatLng here,
    int speed, {
    required bool horizontalControls,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _speedBadge(context, speed),
              const Spacer(),
              if (horizontalControls)
                Row(
                  children: [
                    _zoomButton(here),
                    const SizedBox(width: 8),
                    _routeButton(session),
                  ],
                )
              else
                Column(
                  children: [
                    _zoomButton(here),
                    const SizedBox(height: 8),
                    _routeButton(session),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(LatLng here) {
    return RoundIconButton(
      icon: PhosphorIconsRegular.plus,
      tooltip: 'Zoom in',
      onTap: () =>
          _map.move(here, (_map.camera.zoom + 1).clamp(2, 18).toDouble()),
    );
  }

  Widget _routeButton(Session session) {
    return RoundIconButton(
      icon: PhosphorIconsRegular.path,
      tooltip: 'Show full route',
      onTap: () => _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(session.route.points),
          padding: const EdgeInsets.all(56),
        ),
      ),
    );
  }

  Widget _speedBadge(BuildContext context, int speed) {
    final pal = context.palette;
    return Material(
      color: pal.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: SizedBox(
        width: 58,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$speed',
              style: dataStyle(context, size: 20, weight: FontWeight.w600),
            ),
            Text(
              'km/h',
              style: TextStyle(color: pal.muted, fontSize: 10, height: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomSheet(
    BuildContext context,
    Session session,
    String level,
    RouteSegment? gap,
    Place? recovery,
    LatLng here,
    double remainKm,
    int remainingMin,
    TimeOfDay eta, {
    required bool compact,
    required bool veryCompact,
  }) {
    final pal = context.palette;
    return Frosted(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      lift: 1.4,
      opacity: 0.92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          veryCompact ? 6 : 8,
          16,
          veryCompact ? 6 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: pal.outline.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: veryCompact ? 4 : 8, bottom: 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'End navigation',
                    onPressed: () {
                      _play(false);
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/map');
                      }
                    },
                    icon: const Icon(PhosphorIconsRegular.x),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatDuration(remainingMin),
                          style: TextStyle(
                            color: gap == null ? pal.text : pal.moderate,
                            fontSize: veryCompact ? 22 : 26,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          '${remainKm.toStringAsFixed(0)} km · ${eta.format(context)}',
                          style: TextStyle(color: pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded
                        ? 'Collapse route details'
                        : 'Expand route details',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? PhosphorIconsRegular.caretDown
                          : PhosphorIconsRegular.caretUp,
                      color: pal.muted,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: veryCompact
                            ? 92
                            : compact
                            ? 150
                            : 190,
                      ),
                      child: SingleChildScrollView(
                        child: _expandedDetails(
                          context,
                          session,
                          level,
                          gap,
                          recovery,
                          here,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: pal.secondaryContainer,
                      foregroundColor: pal.onSecondaryContainer,
                    ),
                    onPressed: () {
                      _play(!_playing);
                      setState(() {});
                    },
                    icon: Icon(
                      _playing
                          ? PhosphorIconsFill.pause
                          : PhosphorIconsRegular.car,
                    ),
                    label: Text(_playing ? 'Pause' : 'Drive'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      ref
                          .read(sessionProvider.notifier)
                          .update((s) => s.copyWith(voiceOn: !s.voiceOn));
                      if (!session.voiceOn) await _maybeSpeak();
                    },
                    icon: Icon(
                      session.voiceOn
                          ? PhosphorIconsRegular.speakerHigh
                          : PhosphorIconsRegular.speakerSlash,
                    ),
                    label: Text(session.voiceOn ? 'Voice on' : 'Voice off'),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'More navigation options',
                  onSelected: (value) {
                    if (value == 'reroute_demo') {
                      ref
                          .read(sessionProvider.notifier)
                          .update((s) => s.copyWith(deviated: true));
                      setState(() => _expanded = true);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'reroute_demo',
                      child: Text('Try route-change demo'),
                    ),
                  ],
                  icon: const Icon(PhosphorIconsRegular.dotsThree),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedDetails(
    BuildContext context,
    Session session,
    String level,
    RouteSegment? gap,
    Place? recovery,
    LatLng here,
  ) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route connectivity',
            style: TextStyle(color: pal.beacon, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 12,
            width: double.infinity,
            child: CustomPaint(
              painter: _RouteCoveragePainter(
                segments: session.route.segments,
                operator: session.operatorFilter,
                progress: session.navProgress,
                palette: pal,
              ),
            ),
          ),
          if (gap != null) ...[
            const SizedBox(height: 8),
            Text(
              '${gap.label} · ${gap.km.toStringAsFixed(0)} km · ${formatDuration(gap.min)}',
            ),
          ],
          if (recovery != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.wifiHigh,
                  size: 18,
                  color: pal.beacon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recovery.name} · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km · ${recovery.subtitle}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (session.simulateLoss || level == 'none') ...[
            const SizedBox(height: 8),
            Text(
              'No usable signal here. SOS remains local in this demo.',
              style: TextStyle(color: pal.sos),
            ),
          ],
          if (session.deviated) ...[
            const SizedBox(height: 8),
            Text(
              'You left the selected route. The Nagarjuna Sagar alternative adds time and keeps more recovery towns.',
              style: TextStyle(color: pal.muted),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  ref
                      .read(sessionProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          selectedRouteId: 'sagar',
                          deviated: false,
                          navProgress: 0.12,
                        ),
                      );
                },
                child: const Text('Take the better-signal route'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _follow(LatLng here, double progress) {
    if ((_cameraProgress - progress).abs() < 0.012) return;
    _cameraProgress = progress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.move(here, 12.6);
      } catch (_) {}
    });
  }

  Widget _navMap(Session session, SignalPalette pal, LatLng here) {
    final slices = splitByWeight(
      session.route.points,
      session.route.segments.map((s) => s.km).toList(),
    );
    return FlutterMap(
      mapController: _map,
      options: MapOptions(initialCenter: here, initialZoom: 12.6),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.signalsafe.app',
        ),
        PolylineLayer(
          polylines: [
            for (var i = 0; i < slices.length; i++) ...[
              Polyline(points: slices[i], strokeWidth: 10, color: Colors.white),
              Polyline(
                points: slices[i],
                strokeWidth: 6,
                color:
                    _isLowSignal(
                      session.route.segments[i].levelFor(
                        session.operatorFilter,
                      ),
                    )
                    ? pal.moderate
                    : pal.level(
                        session.route.segments[i].levelFor(
                          session.operatorFilter,
                        ),
                      ),
                pattern:
                    _isLowSignal(
                      session.route.segments[i].levelFor(
                        session.operatorFilter,
                      ),
                    )
                    ? const StrokePattern.dotted()
                    : const StrokePattern.solid(),
              ),
            ],
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: session.destination.point,
              width: 28,
              height: 28,
              child: Icon(PhosphorIconsFill.mapPin, color: pal.route, size: 28),
            ),
            Marker(
              point: here,
              width: 44,
              height: 44,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                child: Icon(
                  PhosphorIconsFill.navigationArrow,
                  color: pal.beacon,
                  size: 27,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isLowSignal(String level) => level == 'none' || level == 'weak';

  String _levelLabel(String level) => switch (level) {
    'good' => 'Good',
    'moderate' => 'Moderate',
    'weak' => 'Weak',
    _ => 'No signal',
  };
}

class _RouteCoveragePainter extends CustomPainter {
  const _RouteCoveragePainter({
    required this.segments,
    required this.operator,
    required this.progress,
    required this.palette,
  });

  final List<RouteSegment> segments;
  final String operator;
  final double progress;
  final SignalPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final totalKm = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.km,
    );
    if (totalKm <= 0) return;
    final centerY = size.height / 2;
    final background = Paint()
      ..color = palette.border
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      background,
    );

    var left = 0.0;
    for (final segment in segments) {
      final width = size.width * segment.km / totalKm;
      final level = segment.levelFor(operator);
      final paint = Paint()
        ..color = palette.level(level)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      if (level == 'none' || level == 'weak') {
        final dotPaint = Paint()..color = palette.moderate;
        for (var x = left + 2.5; x < left + width; x += 8) {
          canvas.drawCircle(Offset(x, centerY), 2.2, dotPaint);
        }
      } else {
        canvas.drawLine(
          Offset(left, centerY),
          Offset(left + width, centerY),
          paint,
        );
      }
      left += width;
    }

    final progressX = size.width * progress.clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(progressX, centerY),
      4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(progressX, centerY),
      2.5,
      Paint()..color = palette.beacon,
    );
  }

  @override
  bool shouldRepaint(_RouteCoveragePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.operator != operator ||
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette;
}
