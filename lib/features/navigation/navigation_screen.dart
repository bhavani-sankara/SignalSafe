import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
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
        final turn =
            _turns[segmentIndex(
              session.route,
              session.navProgress,
            ).clamp(0, _turns.length - 1)];
        final speed = session.simulateLoss
            ? 0
            : 42 + (session.navProgress * 28).round();
        _follow(here, session.navProgress);
        return Scaffold(
          backgroundColor: pal.ink,
          body: Stack(
            children: [
              _navMap(session, pal, here),
              SafeArea(
                child: MaxWidthContent(
                  maxWidth: 760,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            RoundIconButton(
                              icon: PhosphorIconsRegular.x,
                              tooltip: 'End navigation',
                              onTap: () {
                                _play(false);
                                context.pop();
                              },
                            ),
                            const Spacer(),
                            Text(
                              eta.format(context),
                              style: dataStyle(
                                context,
                                size: 20,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          children: [
                            Glass(
                              color: pal.glass,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    turn,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    session.destination.name,
                                    style: TextStyle(color: pal.muted),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      _stat(
                                        context,
                                        '${remainKm.toStringAsFixed(0)} km',
                                        'Remaining',
                                      ),
                                      _stat(
                                        context,
                                        formatDuration(remainingMin),
                                        'Duration',
                                      ),
                                      _stat(context, '$speed', 'km/h'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _timeline(context, session),
                            const SizedBox(height: 12),
                            Glass(
                              color: pal.glass,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SignalChip(level: level),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          operatorLabel(
                                            session.preferredOperator,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SourceTag(source: 'estimated'),
                                    ],
                                  ),
                                  if (gap != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'Upcoming ${gap.levelFor(session.operatorFilter) == 'none' ? 'blackspot' : 'weak stretch'}: ${gap.label}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'About ${gap.km.toStringAsFixed(0)} km · ${formatDuration(gap.min)}',
                                      style: dataStyle(context),
                                    ),
                                  ],
                                  if (recovery != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Next recovery · ${recovery.name}',
                                      style: TextStyle(
                                        color: pal.beacon,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${(distance(here, recovery.point) / 1000).toStringAsFixed(1)} km · ${recovery.subtitle}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (session.simulateLoss || level == 'none')
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Glass(
                                  color: pal.sos.withValues(alpha: 0.16),
                                  child: const Text(
                                    'No usable signal on this stretch. In this demo, SOS remains local and is not sent automatically.',
                                  ),
                                ),
                              ),
                            if (session.deviated)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Glass(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'You left the selected route.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'The Nagarjuna Sagar alternative adds time and keeps more recovery towns.',
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton(
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
                                        child: const Text(
                                          'Take the better-signal route',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Glass(
                          color: pal.glass,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _play(!_playing);
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    _playing
                                        ? PhosphorIconsFill.pause
                                        : PhosphorIconsFill.play,
                                  ),
                                  label: Text(_playing ? 'Pause' : 'Drive'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    ref
                                        .read(sessionProvider.notifier)
                                        .update(
                                          (s) =>
                                              s.copyWith(voiceOn: !s.voiceOn),
                                        );
                                    if (!session.voiceOn) await _maybeSpeak();
                                  },
                                  icon: Icon(
                                    session.voiceOn
                                        ? PhosphorIconsRegular.speakerHigh
                                        : PhosphorIconsRegular.speakerSlash,
                                  ),
                                  label: Text(
                                    session.voiceOn ? 'Voice on' : 'Voice off',
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'More navigation options',
                                onSelected: (value) {
                                  if (value == 'reroute_demo') {
                                    ref
                                        .read(sessionProvider.notifier)
                                        .update(
                                          (s) => s.copyWith(deviated: true),
                                        );
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'reroute_demo',
                                    child: Text('Try route-change demo'),
                                  ),
                                ],
                                icon: const Icon(
                                  PhosphorIconsRegular.dotsThree,
                                ),
                              ),
                            ],
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
      },
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
            for (var i = 0; i < slices.length; i++)
              Polyline(
                points: slices[i],
                strokeWidth: 7,
                color: pal.level(
                  session.route.segments[i].levelFor(session.operatorFilter),
                ),
              ),
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
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: pal.beacon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: dataStyle(context, size: 22, weight: FontWeight.w600),
          ),
          Text(
            label,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _timeline(BuildContext context, Session session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connectivity',
          style: TextStyle(color: context.palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final segment in session.route.segments)
                  Expanded(
                    flex: (segment.km * 10).round().clamp(1, 1000),
                    child: ColoredBox(
                      color: context.palette.level(
                        segment.levelFor(session.operatorFilter),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: session.navProgress,
          minHeight: 3,
          color: context.palette.text,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
}
