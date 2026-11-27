import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

/// Turn-by-turn driving in a night-navy theme. On entry the camera tilts
/// into a 3D-style view and dives to your position. Coverage warnings sit
/// right under the turn card, since that's the thing SignalSafe is for.
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  final _tts = FlutterTts();
  final _map = MapController();
  late final _camera = MapCameraAnimator(map: _map, vsync: this);

  /// 0 = flat overview, 1 = tilted driving view.
  late final AnimationController _tilt = AnimationController(
    vsync: this,
    duration: Motion.cinematic,
  );

  String? _spoken;
  bool _playing = false;
  bool _expanded = false;
  bool _following = true;
  bool _introDone = false;
  double _cameraProgress = -1;

  static const _driveZoom = 13.6;
  static const _tiltRadians = 0.82; // ~47°

  static const _turns = [
    'Head south on the Outer Ring Road',
    'Continue toward Kalwakurthy',
    'Stay on NH 765 through Achampet',
    'Mannanur check post ahead',
    'Forest stretch. Signal will drop',
    'Hairpins toward Dornala',
    'Arrive in Srisailam',
  ];

  static const _turnIcons = [
    PhosphorIconsBold.arrowUp,
    PhosphorIconsBold.arrowUpRight,
    PhosphorIconsBold.arrowUp,
    PhosphorIconsBold.arrowUpLeft,
    PhosphorIconsBold.arrowUp,
    PhosphorIconsBold.arrowBendUpRight,
    PhosphorIconsBold.flagCheckered,
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _camera.dispose();
    _tilt.dispose();
    super.dispose();
  }

  // ── Simulation ────────────────────────────────────────────────────────────

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
    final line = _turns[segmentIndex(
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

  // ── Camera ────────────────────────────────────────────────────────────────

  /// Cinematic entry: start on the whole route, then tilt and dive to you.
  void _intro(Session session, LatLng here) {
    if (_introDone) return;
    _introDone = true;
    final reduced = Motion.reduced(context);
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(session.route.points),
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {}
    if (reduced) {
      _tilt.value = 1;
      _camera.moveTo(here, _driveZoom, duration: Duration.zero);
      return;
    }
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _tilt.animateTo(1, curve: Motion.travel);
      _camera.moveTo(here, _driveZoom, duration: Motion.cinematic);
    });
  }

  void _follow(LatLng here, double progress) {
    if (!_following || !_introDone) return;
    if ((_cameraProgress - progress).abs() < 0.012) return;
    _cameraProgress = progress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tilt.isAnimating) return;
      _camera.moveTo(
        here,
        _map.camera.zoom,
        duration: Motion.of(context, const Duration(milliseconds: 650)),
        curve: Curves.easeInOut,
      );
    });
  }

  void _recenter(LatLng here) {
    setState(() => _following = true);
    if (_tilt.value < 1) _tilt.animateTo(1, curve: Motion.travel);
    _camera.moveTo(
      here,
      _driveZoom,
      duration: Motion.of(context, Motion.recenter),
    );
  }

  void _overview(Session session) {
    setState(() => _following = false);
    _tilt.animateBack(0, curve: Motion.travel);
    _camera.fitBounds(
      LatLngBounds.fromPoints(session.route.points),
      padding: const EdgeInsets.fromLTRB(48, 220, 48, 200),
      duration: Motion.of(context, Motion.recenter),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.of(Brightness.dark),
      child: SessionGate(
        builder: (context, session) {
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
          final remainingMin = (session.route.durationMin *
                  (1 - session.navProgress))
              .round();
          final remainKm = session.route.distanceKm * (1 - session.navProgress);
          final eta = TimeOfDay.fromDateTime(
            DateTime.now().add(Duration(minutes: remainingMin)),
          );
          final turnIndex = segmentIndex(
            session.route,
            session.navProgress,
          ).clamp(0, _turns.length - 1);
          final nextTurn = turnIndex + 1 < _turns.length
              ? _turns[turnIndex + 1]
              : 'Arrive in ${session.destination.name}';
          final speed = session.simulateLoss
              ? 0
              : 42 + (session.navProgress * 28).round();
          final kmToGap = gap == null ? null : _kmToGap(session, gap);
          _follow(here, session.navProgress);

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: NavPalette.surface,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              backgroundColor: NavPalette.night,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: _TiltedMap(
                      tilt: _tilt,
                      maxTilt: _tiltRadians,
                      child: _navMap(session, here),
                    ),
                  ),
                  // Soft fade so the horizon melts into the night sky.
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 200,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [NavPalette.night, Color(0x000B1626)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxHeight < 840;
                            final veryCompact = constraints.maxHeight < 600;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _instructionCard(
                                  session,
                                  _turns[turnIndex],
                                  _turnIcons[turnIndex],
                                  nextTurn,
                                  compact: compact,
                                ),
                                SizedBox(height: veryCompact ? 6 : 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _signalStatus(session, level),
                                  ),
                                ),
                                if (gap != null && !veryCompact)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      0,
                                    ),
                                    child: _coverageWarning(
                                      session,
                                      gap,
                                      kmToGap!,
                                      recovery,
                                      here,
                                      level,
                                      compact: compact,
                                    ),
                                  ),
                                Expanded(
                                  child: _mapActions(session, here, speed),
                                ),
                                _bottomBar(
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
      ),
    );
  }

  double _kmToGap(Session session, RouteSegment gap) {
    final segs = session.route.segments;
    final total = segs.fold<double>(0, (t, s) => t + s.km);
    var start = 0.0;
    for (final s in segs) {
      if (identical(s, gap)) break;
      start += s.km;
    }
    return (start - session.navProgress * total).clamp(0, double.infinity);
  }

  // ── Turn card ─────────────────────────────────────────────────────────────

  Widget _instructionCard(
    Session session,
    String turn,
    IconData icon,
    String nextTurn, {
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: NavPalette.instruction,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 18, 14),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.standard),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: a, child: c),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: compact ? 40 : 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.standard),
                    switchInCurve: Motion.enter,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(a),
                        child: c,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(turn),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.route.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          turn,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 21 : 24,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // "Then" chip tucked under the card.
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.fromLTRB(12, 7, 14, 8),
            decoration: const BoxDecoration(
              color: NavPalette.instructionDeep,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Then',
                  style: TextStyle(
                    color: Color(0xDDFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  PhosphorIconsBold.arrowBendUpRight,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    nextTurn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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

  // ── Signal status + warning ───────────────────────────────────────────────

  Widget _signalStatus(Session session, String level) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: NavPalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignalBars(level: level),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_levelLabel(level)} · ${operatorLabel(session.operatorFilter)} · Estimated',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NavPalette.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverageWarning(
    Session session,
    RouteSegment gap,
    double kmToGap,
    Place? recovery,
    LatLng here,
    String level, {
    required bool compact,
  }) {
    final noSignal = gap.levelFor(session.operatorFilter) == 'none';
    final inside = kmToGap < 0.5;
    final headline = inside
        ? (noSignal ? 'No signal on this stretch' : 'Weak signal on this stretch')
        : '${noSignal ? 'No signal' : 'Weak signal'} in ${kmToGap.toStringAsFixed(kmToGap < 10 ? 1 : 0)} km';
    return Container(
      decoration: BoxDecoration(
        color: NavPalette.warningSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavPalette.warning.withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NavPalette.warning.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsBold.wifiSlash,
                  size: 19,
                  color: NavPalette.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: NavPalette.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      gap.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NavPalette.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${gap.km.toStringAsFixed(0)} km · about ${formatDuration(gap.min)} ${noSignal ? 'without signal' : 'with weak signal'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NavPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recovery != null && !compact) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 50),
                const Icon(
                  PhosphorIconsBold.wifiHigh,
                  size: 15,
                  color: NavPalette.good,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    distance(here, recovery.point) / 1000 < kmToGap
                        ? 'Last strong signal: ${recovery.name} · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km'
                        : 'Signal back at ${recovery.name} · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NavPalette.good,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (session.simulateLoss || level == 'none') ...[
            const SizedBox(height: 8),
            const Text(
              'No usable signal here. SOS remains local in this demo.',
              style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ── Map buttons ───────────────────────────────────────────────────────────

  Widget _mapActions(Session session, LatLng here, int speed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.standard),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SizeTransition(
                    sizeFactor: a,
                    axisAlignment: 1,
                    child: c,
                  ),
                ),
                child: _following
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecenterPill(onTap: () => _recenter(here)),
                      ),
              ),
              _SpeedBubble(speed: speed),
            ],
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NightFab(
                icon: PhosphorIconsRegular.path,
                tooltip: 'Show full route',
                onTap: () => _overview(session),
              ),
              const SizedBox(height: 10),
              _NightFab(
                icon: session.voiceOn
                    ? PhosphorIconsFill.speakerHigh
                    : PhosphorIconsRegular.speakerSlash,
                tooltip: session.voiceOn ? 'Mute voice' : 'Turn on voice',
                onTap: () async {
                  ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(voiceOn: !s.voiceOn));
                  if (!session.voiceOn) await _maybeSpeak();
                },
              ),
              const SizedBox(height: 10),
              _NightFab(
                icon: PhosphorIconsRegular.plus,
                tooltip: 'Zoom in',
                onTap: () {
                  setState(() => _following = false);
                  _camera.moveTo(
                    _map.camera.center,
                    (_map.camera.zoom + 1).clamp(2, 18).toDouble(),
                    duration: Motion.of(context, Motion.standard),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _bottomBar(
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
    return Container(
      decoration: const BoxDecoration(
        color: NavPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(14, veryCompact ? 6 : 8, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: NavPalette.raised,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: veryCompact ? 4 : 8, bottom: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'End navigation',
                  style: IconButton.styleFrom(
                    backgroundColor: NavPalette.raised,
                    foregroundColor: NavPalette.text,
                  ),
                  onPressed: () {
                    _play(false);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/map');
                    }
                  },
                  icon: const Icon(PhosphorIconsBold.x),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(remainingMin),
                        style: TextStyle(
                          color: gap == null
                              ? NavPalette.good
                              : NavPalette.warning,
                          fontSize: veryCompact ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${remainKm.toStringAsFixed(0)} km · ${eta.format(context)}',
                        style: const TextStyle(
                          color: NavPalette.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: _expanded
                      ? 'Collapse route details'
                      : 'Expand route details',
                  style: IconButton.styleFrom(
                    backgroundColor: NavPalette.raised,
                    foregroundColor: NavPalette.text,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: Motion.of(context, Motion.standard),
                    child: const Icon(PhosphorIconsBold.caretUp),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.standard),
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: _expanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: veryCompact
                          ? 92
                          : compact
                          ? 160
                          : 210,
                    ),
                    child: SingleChildScrollView(
                      child: _expandedDetails(
                        session,
                        level,
                        gap,
                        recovery,
                        here,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: NavPalette.route,
                    foregroundColor: NavPalette.night,
                  ),
                  onPressed: () {
                    _play(!_playing);
                    setState(() {});
                  },
                  icon: Icon(
                    _playing ? PhosphorIconsFill.pause : PhosphorIconsFill.car,
                  ),
                  label: Text(_playing ? 'Pause' : 'Drive'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'More navigation options',
                color: NavPalette.raised,
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
                icon: const Icon(
                  PhosphorIconsBold.dotsThree,
                  color: NavPalette.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expandedDetails(
    Session session,
    String level,
    RouteSegment? gap,
    Place? recovery,
    LatLng here,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route connectivity',
            style: TextStyle(
              color: NavPalette.route,
              fontWeight: FontWeight.w600,
            ),
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
                palette: SignalPalette.dark,
              ),
            ),
          ),
          if (gap != null) ...[
            const SizedBox(height: 8),
            Text(
              '${gap.label} · ${gap.km.toStringAsFixed(0)} km · ${formatDuration(gap.min)}',
              style: const TextStyle(color: NavPalette.text),
            ),
          ],
          if (recovery != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.wifiHigh,
                  size: 18,
                  color: NavPalette.good,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recovery.name} · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km · ${recovery.subtitle}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NavPalette.text),
                  ),
                ),
              ],
            ),
          ],
          if (session.deviated) ...[
            const SizedBox(height: 8),
            const Text(
              'You left the selected route. The Nagarjuna Sagar alternative adds time and keeps more recovery towns.',
              style: TextStyle(color: NavPalette.muted),
            ),
            const SizedBox(height: 4),
            TextButton(
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
          ],
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _navMap(Session session, LatLng here) {
    final pal = SignalPalette.dark;
    final slices = splitByWeight(
      session.route.points,
      session.route.segments.map((s) => s.km).toList(),
    );
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: here,
        initialZoom: 9,
        backgroundColor: NavPalette.night,
        onMapReady: () => _intro(session, here),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture) {
            _camera.stop();
            if (_following) setState(() => _following = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.signalsafe.app',
          tileBuilder: _nightTile,
        ),
        PolylineLayer(
          polylines: [
            for (var i = 0; i < slices.length; i++) ...[
              Polyline(
                points: slices[i],
                strokeWidth: 13,
                color: NavPalette.routeCasing,
              ),
              Polyline(
                points: slices[i],
                strokeWidth: 7,
                color: _isLow(
                      session.route.segments[i].levelFor(
                        session.operatorFilter,
                      ),
                    )
                    ? NavPalette.warning
                    : NavPalette.route,
                pattern: _isLow(
                      session.route.segments[i].levelFor(
                        session.operatorFilter,
                      ),
                    )
                    ? const StrokePattern.dotted(spacingFactor: 1.6)
                    : const StrokePattern.solid(),
              ),
            ],
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: session.destination.point,
              width: 36,
              height: 36,
              child: Icon(
                PhosphorIconsFill.mapPin,
                color: pal.destination,
                size: 34,
              ),
            ),
            Marker(
              point: here,
              width: 52,
              height: 52,
              child: Semantics(
                label: 'Your position',
                child: const _NavPuck(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Turns the light OSM tiles into a night-navy map. Brightness is inverted
  /// (so labels turn light) and the result is pulled toward navy: pale land
  /// lands around #0E1A2C, dark text becomes soft blue-white.
  static Widget _nightTile(BuildContext context, Widget tile, TileImage _) {
    const k = -0.267;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        k, k, k, 0, 204, //
        k, k, k, 0, 216, //
        k, k, k, 0, 234, //
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }

  bool _isLow(String level) => level == 'none' || level == 'weak';

  String _levelLabel(String level) => switch (level) {
    'good' => 'Good',
    'moderate' => 'Moderate',
    'weak' => 'Weak',
    _ => 'No signal',
  };
}

// ---------------------------------------------------------------------------
// The fake-3D tilt. flutter_map draws a flat map, so the whole map is laid
// out larger than the screen and rotated back in perspective. The puck sits
// in the lower third and the road ahead recedes toward the horizon.
// ---------------------------------------------------------------------------

class _TiltedMap extends StatelessWidget {
  const _TiltedMap({
    required this.tilt,
    required this.maxTilt,
    required this.child,
  });

  final Animation<double> tilt;
  final double maxTilt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return ClipRect(
          child: AnimatedBuilder(
            animation: tilt,
            builder: (context, child) {
              final t = tilt.value;
              // Oversize grows with the tilt so the corners never show.
              final scaleW = 1 + 0.7 * t;
              final scaleH = 1 + 0.9 * t;
              final mapW = w * scaleW;
              final mapH = h * scaleH;
              // Keep the map's centre (your position) at ~62% of the height.
              final centreY = h * (0.5 + 0.12 * t);
              return OverflowBox(
                maxWidth: mapW,
                maxHeight: mapH,
                minWidth: mapW,
                minHeight: mapH,
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: Offset((w - mapW) / 2, centreY - mapH / 2),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0011)
                      ..rotateX(-maxTilt * t),
                    child: child,
                  ),
                ),
              );
            },
            child: child,
          ),
        );
      },
    );
  }
}

class _NavPuck extends StatelessWidget {
  const _NavPuck();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: NavPalette.route.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: const Icon(
            PhosphorIconsFill.navigationArrow,
            color: NavPalette.instruction,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _NightFab extends StatelessWidget {
  const _NightFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: NavPalette.surface.withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: NavPalette.text, size: 21),
          ),
        ),
      ),
    );
  }
}

class _RecenterPill extends StatelessWidget {
  const _RecenterPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NavPalette.raised,
      shape: const StadiumBorder(),
      elevation: 4,
      shadowColor: Colors.black,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(14, 11, 18, 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsFill.navigationArrow,
                size: 17,
                color: NavPalette.route,
              ),
              SizedBox(width: 8),
              Text(
                'Re-center',
                style: TextStyle(
                  color: NavPalette.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedBubble extends StatelessWidget {
  const _SpeedBubble({required this.speed});

  final int speed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: NavPalette.surface.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: NavPalette.raised, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$speed',
            style: const TextStyle(
              color: NavPalette.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const Text(
            'km/h',
            style: TextStyle(color: NavPalette.muted, fontSize: 10, height: 1),
          ),
        ],
      ),
    );
  }
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
    final totalKm = segments.fold<double>(0, (sum, s) => sum + s.km);
    if (totalKm <= 0) return;
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = NavPalette.raised
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    var left = 0.0;
    for (final segment in segments) {
      final width = size.width * segment.km / totalKm;
      final level = segment.levelFor(operator);
      if (level == 'none' || level == 'weak') {
        final dot = Paint()..color = NavPalette.warning;
        for (var x = left + 2.5; x < left + width; x += 8) {
          canvas.drawCircle(Offset(x, centerY), 2.2, dot);
        }
      } else {
        canvas.drawLine(
          Offset(left, centerY),
          Offset(left + width, centerY),
          Paint()
            ..color = palette.level(level)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
      left += width;
    }

    final x = size.width * progress.clamp(0.0, 1.0);
    canvas.drawCircle(Offset(x, centerY), 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(x, centerY),
      3,
      Paint()..color = NavPalette.instruction,
    );
  }

  @override
  bool shouldRepaint(_RouteCoveragePainter old) =>
      old.segments != segments ||
      old.operator != operator ||
      old.progress != progress ||
      old.palette != palette;
}
