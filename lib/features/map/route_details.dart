import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hud.dart';

// ===========================================================================
// Signal along the route (dummy data until the backend exists)
// ===========================================================================

/// One bar of the signal chart: a stretch of road and its expected strength
/// (0–100) for one network.
class SignalStretch {
  const SignalStretch({
    required this.fromKm,
    required this.toKm,
    required this.strength,
    required this.segment,
  });

  final double fromKm;
  final double toKm;
  final int strength;
  final RouteSegment segment;

  SignalBand get band => SignalBand.of(strength);
}

/// Colour bands for bar heights: tall green, mid amber, short red, and a
/// near-black stub for no signal at all.
enum SignalBand {
  strong('Strong'),
  fair('Fair'),
  weak('Weak'),
  none('No signal');

  const SignalBand(this.word);
  final String word;

  static SignalBand of(int strength) => strength >= 70
      ? strong
      : strength >= 45
      ? fair
      : strength >= 18
      ? weak
      : none;

  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      strong => dark ? const Color(0xFF81C995) : const Color(0xFF4CAF6A),
      fair => dark ? const Color(0xFFFDD663) : const Color(0xFFF2B526),
      weak => dark ? const Color(0xFFF28B82) : const Color(0xFFE8685D),
      none => dark ? const Color(0xFFBFC5CE) : const Color(0xFF2B3036),
    };
  }
}

/// Splits [route] into ~[count] equal stretches and gives each a strength
/// for [op]. Derived from the route's segment levels plus a small, stable
/// wobble so neighbouring bars don't look copy-pasted.
List<SignalStretch> signalStretches(
  JourneyRoute route,
  String op, {
  int count = 12,
}) {
  final total = route.segments.fold<double>(0, (t, s) => t + s.km);
  final step = total / count;
  final seed = '${route.id}$op'.codeUnits.fold<int>(7, (a, c) => a * 31 + c);
  final out = <SignalStretch>[];
  for (var i = 0; i < count; i++) {
    final mid = step * (i + 0.5);
    var acc = 0.0;
    var seg = route.segments.last;
    for (final s in route.segments) {
      acc += s.km;
      if (mid <= acc) {
        seg = s;
        break;
      }
    }
    final wobble = ((seed + i * 977) % 17) - 8; // −8 … +8
    final strength = switch (seg.levelFor(op)) {
      'good' => 84 + wobble,
      'moderate' => 58 + wobble,
      'weak' => 30 + wobble,
      _ => (wobble + 8) ~/ 3, // 0 … 5
    };
    out.add(
      SignalStretch(
        fromKm: step * i,
        toKm: step * (i + 1),
        strength: strength.clamp(0, 100),
        segment: seg,
      ),
    );
  }
  return out;
}

/// "Mannanur – Dornala forest" → ("Mannanur", "Dornala forest").
(String, String?) _ends(String label) {
  final parts = label.split(' – ');
  return (parts.first, parts.length > 1 ? parts.last : null);
}

String _near(String label) {
  final (a, b) = _ends(label);
  return b == null ? 'near $a' : 'between $a and $b';
}

// ---------------------------------------------------------------------------
// The chart
// ---------------------------------------------------------------------------

/// Google's "Traffic" histogram, reused for signal: one bar per stretch of
/// road, height = signal strength, colour = band. Tap a bar for details.
class SignalStretchChart extends StatefulWidget {
  const SignalStretchChart({super.key, required this.route, required this.op});

  final JourneyRoute route;
  final String op;

  @override
  State<SignalStretchChart> createState() => _SignalStretchChartState();
}

class _SignalStretchChartState extends State<SignalStretchChart> {
  int? _selected;

  @override
  void didUpdateWidget(SignalStretchChart old) {
    super.didUpdateWidget(old);
    if (old.route.id != widget.route.id || old.op != widget.op) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bars = signalStretches(widget.route, widget.op);
    final total = bars.last.toKm;
    const plot = 84.0;
    final sel = _selected == null ? null : bars[_selected!];

    return Semantics(
      label:
          'Signal along the route for ${operatorLabel(widget.op)}. '
          '${bars.where((b) => b.band == SignalBand.none).length} of '
          '${bars.length} stretches have no signal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption row: the tapped stretch, or the legend.
          SizedBox(
            height: 22,
            child: AnimatedSwitcher(
              duration: Motion.quick,
              child: sel == null
                  ? const _Legend(key: ValueKey('legend'))
                  : Align(
                      key: ValueKey(_selected),
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: sel.band.word,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: sel.band == SignalBand.none
                                    ? pal.text
                                    : sel.band.color(context),
                              ),
                            ),
                            TextSpan(
                              text:
                                  '  ·  km ${sel.fromKm.round()}–${sel.toKm.round()}'
                                  '  ·  ${sel.segment.label}',
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: pal.muted),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: plot + 16,
            child: Stack(
              children: [
                // Dashed "full signal" ceiling with its label, like the
                // "1 hr 15 min" line on the traffic chart.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: const Size.fromHeight(1),
                          painter: _DashPainter(pal.border),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Full signal',
                        style: TextStyle(fontSize: 11, color: pal.muted),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: plot,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < bars.length; i++)
                        Expanded(
                          child: _Bar(
                            stretch: bars[i],
                            index: i,
                            dimmed: _selected != null && _selected != i,
                            selected: _selected == i,
                            onTap: () => setState(
                              () => _selected = _selected == i ? null : i,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: pal.border),
          const SizedBox(height: 6),
          // Distance ticks under the bars.
          Row(
            children: [
              for (final km in [0.0, total / 3, total * 2 / 3, total])
                Expanded(
                  child: Text(
                    km == 0 ? 'Start' : '${km.round()} km',
                    textAlign: km == 0
                        ? TextAlign.left
                        : km == total
                        ? TextAlign.right
                        : TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: pal.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.stretch,
    required this.index,
    required this.dimmed,
    required this.selected,
    required this.onTap,
  });

  final SignalStretch stretch;
  final int index;
  final bool dimmed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = stretch.band;
    // No signal still gets a short stub, so the gap reads as "black bar",
    // not "missing data".
    final target = band == SignalBand.none
        ? 0.07
        : (stretch.strength / 100).clamp(0.12, 1.0);
    return Semantics(
      button: true,
      label:
          'km ${stretch.fromKm.round()} to ${stretch.toKm.round()}, ${band.word}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: Motion.of(
              context,
              Duration(milliseconds: 420 + index * 30),
            ),
            curve: Motion.enter,
            builder: (context, v, _) => Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: v.clamp(0.0, 1.0),
                widthFactor: 1,
                child: AnimatedOpacity(
                  duration: Motion.quick,
                  opacity: dimmed ? 0.35 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: band.color(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                      border: selected
                          ? Border.all(color: context.palette.text, width: 1.5)
                          : null,
                    ),
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

class _Legend extends StatelessWidget {
  const _Legend({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Row(
      children: [
        for (final b in SignalBand.values) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: b.color(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(b.word, style: TextStyle(fontSize: 12, color: pal.muted)),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Notes under the chart ("Object on road", "Construction on …")
// ---------------------------------------------------------------------------

class SignalNotes extends StatelessWidget {
  const SignalNotes({
    super.key,
    required this.route,
    required this.op,
    this.blackspot,
  });

  final JourneyRoute route;
  final String op;
  final Blackspot? blackspot;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final name = operatorLabel(op);
    final notes = <Widget>[];
    final segs = route.segments;
    var lastLow = -1;
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final level = s.levelFor(op);
      if (level != 'none' && level != 'weak') continue;
      lastLow = i;
      final none = level == 'none';
      notes.add(
        _NoteRow(
          icon: none
              ? PhosphorIconsBold.cellSignalSlash
              : PhosphorIconsBold.cellSignalLow,
          tint: none ? SignalBand.none : SignalBand.weak,
          title: none
              ? 'No $name signal ${_near(s.label)}'
              : 'Weak $name signal ${_near(s.label)}',
          subtitle:
              '${s.km.round()} km  ·  about ${formatDuration(s.min)}'
              '${none ? '  ·  calls and SOS may not go through' : ''}',
        ),
      );
    }
    if (lastLow >= 0 && lastLow + 1 < segs.length) {
      final back = _ends(segs[lastLow + 1].label).$1;
      notes.add(
        _NoteRow(
          icon: PhosphorIconsBold.cellSignalFull,
          tint: SignalBand.strong,
          title: '$name signal returns near $back',
          subtitle: 'Queued messages send automatically here',
        ),
      );
    }
    if (blackspot != null && notes.isNotEmpty) {
      notes.add(
        _NoteRow(
          icon: PhosphorIconsBold.warning,
          tint: SignalBand.fair,
          title: blackspot!.name,
          subtitle: blackspot!.warning,
        ),
      );
    }
    if (notes.isEmpty) {
      notes.add(
        _NoteRow(
          icon: PhosphorIconsBold.cellSignalFull,
          tint: SignalBand.strong,
          title: 'Steady $name signal the whole way',
          subtitle: 'No dead zones expected on this route',
        ),
      );
    }
    return DefaultTextStyle.merge(
      style: TextStyle(color: pal.text),
      child: Column(children: notes),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final SignalBand tint;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final c = tint.color(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tint == SignalBand.none
                  ? (dark ? const Color(0xFF3A4150) : const Color(0xFF2B3036))
                  : c,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: tint == SignalBand.fair || tint == SignalBand.none
                  ? (tint == SignalBand.none
                        ? Colors.white
                        : const Color(0xFF3B2A00))
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    color: pal.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: pal.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Text-only step list
// ===========================================================================

class RouteStep {
  const RouteStep(
    this.icon,
    this.text, {
    this.note,
    this.warn = false,
    this.km,
  });

  final IconData icon;
  final String text;
  final String? note;
  final bool warn;

  /// Distance until the next step; drawn as the "80 m ———" divider.
  final double? km;
}

/// Dummy turn list. NH 765 has a hand-written one; other routes get steps
/// built from their segments.
List<RouteStep> routeSteps(JourneyRoute route, String op, String destination) {
  if (route.id == 'nh765') {
    return [
      const RouteStep(
        PhosphorIconsBold.arrowUp,
        'Head south on Gachibowli Main Rd',
        km: 0.65,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowBendUpLeft,
        'Turn left onto Old Mumbai Hwy',
        note: 'Pass by HP Petrol Gachibowli (on the left in 450 m)',
        km: 3.2,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowUpRight,
        'Take the ramp onto Outer Ring Rd',
        km: 14,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowBendUpRight,
        'Take exit 15 toward Srisailam Hwy / NH 765',
        km: 1.1,
      ),
      RouteStep(
        PhosphorIconsBold.arrowUp,
        'Continue on NH 765 through Kalwakurthy',
        note: '${operatorLabel(op)} signal is good until Achampet',
        km: 74,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowUpRight,
        'Keep right to stay on NH 765 toward Achampet',
        km: 41,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowUp,
        'Continue past the Mannanur forest check post',
        note:
            'Signal drops for about 54 min after this. Save the route offline '
            'before you get here.',
        warn: true,
        km: 38,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowUp,
        'Continue through Dornala',
        note: 'Signal comes back here',
        km: 16,
      ),
      const RouteStep(
        PhosphorIconsBold.arrowBendUpRight,
        'Turn right toward Srisailam temple',
        km: 1.2,
      ),
      RouteStep(PhosphorIconsFill.mapPin, 'Arrive at $destination'),
    ];
  }
  final steps = <RouteStep>[
    const RouteStep(PhosphorIconsBold.arrowUp, 'Head south', km: 0.4),
    const RouteStep(
      PhosphorIconsBold.arrowBendUpLeft,
      'Turn left onto Outer Ring Rd',
      km: 12,
    ),
  ];
  for (final s in route.segments) {
    final level = s.levelFor(op);
    final low = level == 'none' || level == 'weak';
    steps.add(
      RouteStep(
        PhosphorIconsBold.arrowUp,
        'Continue ${_near(s.label).replaceFirst('between', 'from').replaceFirst(' and ', ' to ')}',
        note: low
            ? '${level == 'none' ? 'No' : 'Weak'} ${operatorLabel(op)} signal '
                  'for about ${formatDuration(s.min)}'
            : null,
        warn: low,
        km: s.km,
      ),
    );
  }
  steps.add(RouteStep(PhosphorIconsFill.mapPin, 'Arrive at $destination'));
  return steps;
}

class StepList extends StatelessWidget {
  const StepList({super.key, required this.steps, required this.origin});

  final List<RouteStep> steps;
  final String origin;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepRow(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: pal.beacon,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: pal.beacon.withValues(alpha: 0.3),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          text: 'Your location',
        ),
        const _StepDivider(),
        for (final s in steps) ...[
          _StepRow(
            leading: Icon(
              s.icon,
              size: 22,
              color: s.icon == PhosphorIconsFill.mapPin
                  ? pal.destination
                  : pal.text,
            ),
            text: s.text,
            note: s.note,
            warn: s.warn,
          ),
          if (s.km != null) _StepDivider(km: s.km),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.leading,
    required this.text,
    this.note,
    this.warn = false,
  });

  final Widget leading;
  final String text;
  final String? note;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 66, child: Center(child: leading)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(fontSize: 16, height: 1.35, color: pal.text),
                ),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        warn
                            ? PhosphorIconsFill.warningCircle
                            : PhosphorIconsFill.info,
                        size: 17,
                        color: warn ? pal.moderate : pal.beacon,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note!,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: pal.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider({this.km});

  final double? km;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final label = km == null
        ? null
        : km! < 1
        ? '${(km! * 1000).round()} m'
        : '${km! >= 10 ? km!.round() : km!.toStringAsFixed(1)} km';
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Row(
        children: [
          if (label != null) ...[
            Text(label, style: TextStyle(fontSize: 14, color: pal.muted)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Container(height: 1, color: pal.border)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini version of the chart, for cards
// ---------------------------------------------------------------------------

/// Compact signal bars for a trip card: same bands and heights as the Drive
/// chart, no legend or axis.
class MiniSignalBars extends StatelessWidget {
  const MiniSignalBars({
    super.key,
    required this.route,
    required this.op,
    this.height = 40,
  });

  final JourneyRoute route;
  final String op;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bars = signalStretches(route, op, count: 18);
    final none = bars.where((b) => b.band == SignalBand.none).length;
    return Semantics(
      label:
          'Signal along the trip for ${operatorLabel(op)}: '
          '$none of ${bars.length} stretches with no signal',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: bars[i].band == SignalBand.none
                          ? 0.1
                          : (bars[i].strength / 100).clamp(0.15, 1.0),
                    ),
                    duration: Motion.of(
                      context,
                      Duration(milliseconds: 380 + i * 20),
                    ),
                    curve: Motion.enter,
                    builder: (context, v, _) => FractionallySizedBox(
                      heightFactor: v,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: bars[i].band.color(context),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
