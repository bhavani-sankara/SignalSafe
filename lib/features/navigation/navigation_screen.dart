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
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
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
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _signalStatus(
                                      context,
                                      session,
                                      level,
                                    ),
                                  ),
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
                                child: AnimatedOpacity(
                                  opacity: _expanded ? 0 : 1,
                                  duration: Motion.quick,
                                  child: IgnorePointer(
                                    ignoring: _expanded,
                                    child: _mapActions(
                                      context,
                                      session,
                                      here,
                                      speed,
                                      horizontalControls: veryCompact,
                                    ),
                                  ),
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

  // ---------------------------------------------------------------------
  // Guidance
  // ---------------------------------------------------------------------

  IconData _maneuverIcon(String turn) {
    final t = turn.toLowerCase();
    if (t.startsWith('arrive')) return PhosphorIconsFill.flagCheckered;
    if (t.contains('signal will drop')) return PhosphorIconsFill.wifiSlash;
    if (t.contains('hairpin')) return PhosphorIconsBold.arrowBendUpRight;
    if (t.contains('check post')) return PhosphorIconsBold.shieldChevron;
    return PhosphorIconsBold.arrowUp;
  }

  /// Kilometres left in the current guidance step.
  double _kmToNextStep(Session session) {
    final segs = session.route.segments;
    final total = segs.fold<double>(0, (t, s) => t + s.km);
    if (total <= 0) return 0;
    final i = segmentIndex(session.route, session.navProgress);
    var endKm = 0.0;
    for (var k = 0; k <= i && k < segs.length; k++) {
      endKm += segs[k].km;
    }
    final doneKm = total * session.navProgress;
    return (endKm - doneKm).clamp(0, total).toDouble();
  }

  /// Kilometres until [gap] begins (0 when already inside it).
  double _kmToGap(Session session, RouteSegment gap) {
    final segs = session.route.segments;
    final total = segs.fold<double>(0, (t, s) => t + s.km);
    var startKm = 0.0;
    for (final s in segs) {
      if (identical(s, gap) || s.label == gap.label) break;
      startKm += s.km;
    }
    return (startKm - total * session.navProgress).clamp(0, total).toDouble();
  }

  String _km(double km) => km < 1
      ? '${(km * 1000 / 50).round() * 50} m'
      : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  Widget _instructionBanner(
    BuildContext context,
    Session session,
    String turn,
    String nextTurn,
    Color background,
    Color foreground, {
    required bool compact,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = dark ? const Color(0xFF0F3D37) : const Color(0xFF0A5C52);
    final bottom = dark ? const Color(0xFF0B2F2A) : const Color(0xFF07463F);
    const fg = Colors.white;
    final toStep = _kmToNextStep(session);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: floatShadow(context, lift: 1.2),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                compact ? 10 : 14,
                18,
                compact ? 10 : 14,
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: Motion.standard,
                    transitionBuilder: (c, a) => ScaleTransition(
                      scale: Tween(begin: 0.7, end: 1.0).animate(
                        CurvedAnimation(parent: a, curve: Motion.enter),
                      ),
                      child: FadeTransition(opacity: a, child: c),
                    ),
                    child: Container(
                      key: ValueKey(turn),
                      width: compact ? 52 : 64,
                      height: compact ? 52 : 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _maneuverIcon(turn),
                        size: compact ? 30 : 38,
                        color: fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _km(toStep),
                          style: TextStyle(
                            color: fg,
                            fontSize: compact ? 22 : 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: Motion.standard,
                          child: Text(
                            turn,
                            key: ValueKey(turn),
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: compact ? 15 : 17,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${session.route.name} · toward ${session.destination.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.72),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "Then" tab tucked under the main card.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 14, top: 0),
              padding: EdgeInsets.fromLTRB(
                12,
                compact ? 6 : 8,
                14,
                compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: bottom.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                boxShadow: floatShadow(context, lift: 0.5),
              ),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Then',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(_maneuverIcon(nextTurn), size: 16, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      nextTurn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------

  Widget _signalStatus(BuildContext context, Session session, String level) {
    final pal = context.palette;
    final color = pal.levelFill(level);
    return Frosted(
      borderRadius: BorderRadius.circular(99),
      lift: 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Center(child: SignalBars(level: level)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _levelLabel(level),
                      style: TextStyle(
                        color: pal.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          '  ${operatorLabel(session.operatorFilter)} · Estimated',
                      style: TextStyle(color: pal.muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
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
      child: Frosted(
        borderRadius: BorderRadius.circular(18),
        lift: 0.6,
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
                  color: pal.levelFill('weak'),
                ),
                const SizedBox(width: 6),
                Text(
                  '${gap.km.toStringAsFixed(0)} km · ${formatDuration(gap.min)}',
                  style: TextStyle(
                    color: pal.text,
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
    final inGap = _kmToGap(session, gap) <= 0.05;
    final accent = pal.levelFill(noSignal ? 'weak' : 'moderate');
    return Frosted(
      borderRadius: BorderRadius.circular(24),
      lift: 0.8,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 38 : 44,
                  height: compact ? 38 : 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIconsFill.wifiSlash,
                    color: accent,
                    size: compact ? 19 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inGap
                            ? (noSignal
                                  ? 'In a blackspot now'
                                  : 'Weak signal now')
                            : '${noSignal ? 'Blackspot' : 'Weak signal'} in ${_km(_kmToGap(session, gap))}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        gap.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDuration(gap.min),
                      style: TextStyle(
                        color: pal.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      noSignal ? 'offline' : 'weak',
                      style: TextStyle(color: pal.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 14,
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
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pal.route.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.wifiHigh,
                        color: pal.beacon,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Signal back at ${recovery.name}',
                                style: TextStyle(
                                  color: pal.beacon,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' · ${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km · ${recovery.subtitle}',
                                style: TextStyle(color: pal.muted),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
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

  // ---------------------------------------------------------------------
  // Map controls
  // ---------------------------------------------------------------------

  Widget _mapActions(
    BuildContext context,
    Session session,
    LatLng here,
    int speed, {
    required bool horizontalControls,
  }) {
    final controls = [
      _ctrl(
        PhosphorIconsRegular.plus,
        'Zoom in',
        () => _map.move(here, (_map.camera.zoom + 1).clamp(2, 18).toDouble()),
      ),
      _ctrl(
        PhosphorIconsRegular.minus,
        'Zoom out',
        () => _map.move(here, (_map.camera.zoom - 1).clamp(2, 18).toDouble()),
      ),
      _ctrl(
        PhosphorIconsRegular.path,
        'Show full route',
        () => _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(session.route.points),
            padding: const EdgeInsets.all(56),
          ),
        ),
      ),
      _ctrl(PhosphorIconsRegular.crosshair, 'Re-centre', () {
        _cameraProgress = -1;
        _map.move(here, 12.6);
      }),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _speedBadge(context, speed),
              const Spacer(),
              Frosted(
                borderRadius: BorderRadius.circular(18),
                lift: 0.7,
                child: horizontalControls
                    ? Row(mainAxisSize: MainAxisSize.min, children: controls)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: controls,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctrl(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 21, color: context.palette.text),
        ),
      ),
    );
  }

  Widget _speedBadge(BuildContext context, int speed) {
    final pal = context.palette;
    return Semantics(
      label: 'Speed $speed kilometres per hour',
      child: ExcludeSemantics(
        child: Frosted(
          borderRadius: BorderRadius.circular(20),
          opacity: 0.95,
          lift: 0.8,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: Motion.quick,
                  child: Text(
                    '$speed',
                    key: ValueKey(speed),
                    style: TextStyle(
                      color: pal.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'km/h',
                  style: TextStyle(color: pal.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Trip panel
  // ---------------------------------------------------------------------

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
    final etaColor = gap == null ? pal.good : pal.text;
    return Frosted(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      lift: 1.4,
      opacity: 0.94,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, veryCompact ? 8 : 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -150 && !_expanded) setState(() => _expanded = true);
                if (v > 150 && _expanded) setState(() => _expanded = false);
              },
              child: Column(
                children: [
                  const SheetGrabber(),
                  Padding(
                    padding: EdgeInsets.only(
                      top: veryCompact ? 0 : 4,
                      bottom: veryCompact ? 8 : 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDuration(remainingMin),
                                style: TextStyle(
                                  color: etaColor,
                                  fontSize: veryCompact ? 24 : 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${remainKm.toStringAsFixed(0)} km',
                                    ),
                                    const TextSpan(text: '  ·  '),
                                    TextSpan(
                                      text: 'Arrive ${eta.format(context)}',
                                      style: TextStyle(
                                        color: pal.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _expanded
                              ? 'Collapse route details'
                              : 'Expand route details',
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: Motion.standard,
                            curve: Motion.settle,
                            child: Icon(
                              PhosphorIconsRegular.caretUp,
                              color: pal.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'End navigation',
                          child: Material(
                            color: const Color(0xFFC5221F),
                            shape: const StadiumBorder(),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () {
                                _play(false);
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/map');
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIconsBold.x,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Exit',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!veryCompact)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: session.navProgress),
                          duration: Motion.emphasized,
                          curve: Motion.settle,
                          builder: (context, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 4,
                            color: pal.beacon,
                            backgroundColor: pal.border.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: Motion.standard,
              curve: Motion.settle,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: veryCompact
                            ? 92
                            : compact
                            ? 170
                            : 260,
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
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      _play(!_playing);
                      setState(() {});
                    },
                    icon: Icon(
                      _playing
                          ? PhosphorIconsFill.pause
                          : PhosphorIconsFill.car,
                    ),
                    label: Text(_playing ? 'Pause' : 'Drive'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: session.voiceOn ? 'Mute voice' : 'Turn voice on',
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(50, 50),
                      backgroundColor: session.voiceOn
                          ? pal.primaryContainer
                          : pal.elevated,
                      foregroundColor: session.voiceOn
                          ? pal.onPrimaryContainer
                          : pal.muted,
                    ),
                    onPressed: () async {
                      ref
                          .read(sessionProvider.notifier)
                          .update((s) => s.copyWith(voiceOn: !s.voiceOn));
                      if (!session.voiceOn) await _maybeSpeak();
                    },
                    icon: Icon(
                      session.voiceOn
                          ? PhosphorIconsFill.speakerHigh
                          : PhosphorIconsRegular.speakerSlash,
                    ),
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
                  icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
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
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: pal.text, fontWeight: FontWeight.w600),
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
          const SizedBox(height: 6),
          for (var i = 0; i < session.route.segments.length; i++)
            Opacity(
              opacity: i < segmentIndex(session.route, session.navProgress)
                  ? 0.45
                  : 1,
              child: SegmentRow(
                segment: session.route.segments[i],
                level: session.route.segments[i].levelFor(
                  session.operatorFilter,
                ),
                first: i == 0,
                last: i == session.route.segments.length - 1,
              ),
            ),
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
    final travelled = session.navProgress;
    final total = slices.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(initialCenter: here, initialZoom: 12.6),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.signalsafe.app',
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        PolylineLayer(
          polylines: [
            for (var i = 0; i < slices.length; i++) ...[
              Polyline(
                points: slices[i],
                strokeWidth: 12,
                color: dark ? const Color(0xFF0E1412) : Colors.white,
              ),
              Polyline(
                points: slices[i],
                strokeWidth: 7,
                color: (i + 1) / total <= travelled
                    ? pal.outline.withValues(alpha: 0.6)
                    : pal.levelFill(
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
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: Icon(
                PhosphorIconsFill.mapPin,
                color: pal.destination,
                size: 40,
              ),
            ),
            Marker(
              point: here,
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: pal.beacon.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      PhosphorIconsFill.navigationArrow,
                      color: pal.beacon,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap')],
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
        ..color = palette.levelFill(level)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      if (level == 'none' || level == 'weak') {
        final dotPaint = Paint()..color = palette.levelFill(level);
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
