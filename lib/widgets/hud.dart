import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

class MaxWidthContent extends StatelessWidget {
  const MaxWidthContent({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass / card surface
// ---------------------------------------------------------------------------

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20.0,
    this.color,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? pal.surface,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        // Borders only in dark mode, where surfaces need separating.
        side: dark ? BorderSide(color: pal.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Route preview — illustrative map thumbnail
// ---------------------------------------------------------------------------

class RoutePreview extends StatelessWidget {
  const RoutePreview({super.key, this.height = 124});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Illustrated route preview',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _RoutePreviewPainter(context.palette)),
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  const _RoutePreviewPainter(this.palette);

  final SignalPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = palette == SignalPalette.dark;
    final bounds = Offset.zero & size;

    // Background
    canvas.drawRect(
      bounds,
      Paint()
        ..color = dark ? const Color(0xFF0E1512) : const Color(0xFFEEEBE3),
    );

    // Green area (park/forest)
    final park = Path()
      ..moveTo(size.width * 0.46, size.height * 0.18)
      ..lineTo(size.width * 0.9, size.height * 0.24)
      ..lineTo(size.width * 0.93, size.height * 0.9)
      ..lineTo(size.width * 0.4, size.height * 0.95)
      ..close();
    canvas.drawPath(
      park,
      Paint()
        ..color = dark
            ? const Color(0xFF1A2E1E)
            : const Color(0xFFC8E6C9).withValues(alpha: 0.7),
    );

    // Water body
    final water = Path()
      ..moveTo(size.width * 0.0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.08, size.height * 0.18,
        size.width * 0.22, size.height * 0.26,
        size.width * 0.18, size.height * 0.46,
      )
      ..lineTo(size.width * 0.0, size.height * 0.5)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..color = dark
            ? const Color(0xFF162A30)
            : const Color(0xFFB3E5FC).withValues(alpha: 0.6),
    );

    // Roads (white)
    final roadPaint = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final road = Path()
      ..moveTo(-size.width * 0.05, size.height * 0.72)
      ..cubicTo(
        size.width * 0.22, size.height * 0.5,
        size.width * 0.65, size.height * 1.02,
        size.width * 1.05, size.height * 0.52,
      );
    canvas.drawPath(road, roadPaint);

    final sideRoad = Path()
      ..moveTo(size.width * 0.2, -size.height * 0.1)
      ..cubicTo(
        size.width * 0.3, size.height * 0.3,
        size.width * 0.1, size.height * 0.74,
        size.width * 0.22, size.height * 1.1,
      );
    canvas.drawPath(sideRoad, roadPaint..strokeWidth = 5);

    // Route casing (white glow)
    final route = Path()
      ..moveTo(size.width * 0.22, size.height * 0.14)
      ..cubicTo(
        size.width * 0.36, size.height * 0.5,
        size.width * 0.62, size.height * 0.78,
        size.width * 0.85, size.height * 0.54,
      );

    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    // Route line — teal with amber patch in the middle
    final metrics = route.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final m = metrics.first;
      final totalLen = m.length;

      void drawSegment(double from, double to, Color color) {
        final sub = m.extractPath(totalLen * from, totalLen * to);
        canvas.drawPath(
          sub,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }

      drawSegment(0.0, 0.42, palette.route);
      drawSegment(0.42, 0.68, palette.moderate);
      drawSegment(0.68, 1.0, palette.route);
    }

    // Dotted overlay on the amber segment
    final amberDot = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    if (metrics.isNotEmpty) {
      final m = metrics.first;
      for (var t = 0.44; t < 0.66; t += 0.06) {
        final pt = m.getTangentForOffset(m.length * t)?.position;
        if (pt != null) canvas.drawCircle(pt, 2.5, amberDot);
      }
    }

    // Origin dot
    final origin = Offset(size.width * 0.22, size.height * 0.14);
    canvas.drawCircle(
        origin, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      origin,
      10,
      Paint()
        ..color = palette.beacon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(origin, 4, Paint()..color = palette.beacon);

    // Destination pin
    final dest = Offset(size.width * 0.85, size.height * 0.54);
    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: dest, radius: 12));
    canvas.drawPath(pinPath, Paint()..color = palette.destination);
    canvas.drawCircle(dest, 4.5, Paint()..color = Colors.white);

    // Vignette
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: dark ? 0.28 : 0.1),
      ],
    ).createShader(bounds);
    canvas.drawRect(bounds, Paint()..shader = vignette);
  }

  @override
  bool shouldRepaint(_RoutePreviewPainter old) => old.palette != palette;
}

// ---------------------------------------------------------------------------
// Signal chips & bars
// ---------------------------------------------------------------------------

class SignalChip extends StatelessWidget {
  const SignalChip({
    super.key,
    required this.level,
    this.label,
    this.compact = false,
  });

  final String level;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final color = pal.level(level);
    final foreground = pal.onLevelContainer(level);
    final background = pal.levelContainer(level);
    final text = label ??
        switch (level) {
          'good' => 'Good signal',
          'moderate' => 'Moderate',
          'weak' => 'Weak signal',
          _ => 'No signal',
        };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final activeBars = switch (level) {
      'good' => 4,
      'moderate' => 3,
      'weak' => 2,
      _ => 1,
    };
    const heights = [6.0, 10.0, 14.0, 18.0];
    return ExcludeSemantics(
      child: SizedBox(
        width: 22,
        height: 22,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: 3,
                height: heights[i],
                decoration: BoxDecoration(
                  color: i < activeBars ? pal.level(level) : pal.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Round map control button
// ---------------------------------------------------------------------------

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.sos = false,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;
  final bool sos;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = sos
        ? pal.sos
        : selected
            ? pal.secondaryContainer
            : pal.surface;
    final fg = sos
        ? Colors.white
        : selected
            ? pal.onSecondaryContainer
            : pal.text;

    return Tooltip(
      message: tooltip ?? '',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: selected || sos ? null : softShadow(context),
        ),
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: fg, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section headings
// ---------------------------------------------------------------------------

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.beacon,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.palette.text,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(color: context.palette.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Source tag
// ---------------------------------------------------------------------------

class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final label = switch (source) {
      'measured' => 'Measured',
      'metadata' => 'Tower metadata',
      'community' => 'Community',
      _ => 'Estimated',
    };
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.3,
        color: pal.muted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signal coverage bar  (the chunky segmented infographic)
// ---------------------------------------------------------------------------

class SignalCoverageBar extends StatelessWidget {
  const SignalCoverageBar({
    super.key,
    required this.stats,
    this.height = 10,
    this.showLabels = false,
    this.showLegend = false,
  });

  final Map<String, int> stats;
  final double height;
  final bool showLabels;

  /// A compact "● 45% strong  ● 28% fair …" key under the bar.
  final bool showLegend;

  static const _levels = ['good', 'moderate', 'weak', 'none'];

  static String levelName(String level) => switch (level) {
        'good' => 'strong',
        'moderate' => 'fair',
        'weak' => 'weak',
        _ => 'none',
      };

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    // Levels with 0% get no sliver at all; each remaining segment is its
    // own rounded capsule separated by a small gap.
    final present = [
      for (final l in _levels)
        if ((stats[l] ?? 0) > 0) l,
    ];
    final gap = height >= 6 ? 3.0 : 2.0;

    return Semantics(
      label: 'Signal coverage: '
          '${stats['good'] ?? 0}% good, '
          '${stats['moderate'] ?? 0}% moderate, '
          '${stats['weak'] ?? 0}% weak, '
          '${stats['none'] ?? 0}% no signal',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < present.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      flex: stats[present[i]]!.clamp(1, 100),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pal.level(present[i]),
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showLabels) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < present.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      flex: stats[present[i]]!.clamp(1, 100),
                      child: Text(
                        '${stats[present[i]]}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: pal.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (showLegend) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final l in present)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pal.level(l),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${stats[l]}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: pal.text,
                                ),
                              ),
                              TextSpan(text: ' ${levelName(l)}'),
                            ],
                          ),
                          style: TextStyle(fontSize: 12, color: pal.muted),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat pill row for route cards
// ---------------------------------------------------------------------------

class RouteStatRow extends StatelessWidget {
  const RouteStatRow({
    super.key,
    required this.distanceKm,
    required this.durationMin,
    this.lowSignalMin = 0,
    this.iconData,
  });

  final double distanceKm;
  final int durationMin;
  final int lowSignalMin;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _pill(
          context,
          icon: PhosphorIconsRegular.path,
          label: '${distanceKm.toStringAsFixed(0)} km',
          color: pal.muted,
        ),
        _pill(
          context,
          icon: PhosphorIconsRegular.clock,
          label: formatDuration(durationMin),
          color: pal.muted,
        ),
        if (lowSignalMin > 0)
          _pill(
            context,
            icon: PhosphorIconsRegular.wifiSlash,
            label: '$lowSignalMin min low signal',
            color: pal.moderate,
            tinted: true,
          ),
      ],
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    bool tinted = false,
  }) {
    final pal = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tinted
            ? pal.warningContainer.withValues(alpha: 0.6)
            : pal.elevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IconData categoryIcon(String category) {
  return switch (category) {
    'hospital' => PhosphorIconsRegular.firstAid,
    'police' => PhosphorIconsRegular.shieldChevron,
    'fuel' => PhosphorIconsRegular.gasPump,
    'hotel' => PhosphorIconsRegular.bed,
    'restaurant' => PhosphorIconsRegular.forkKnife,
    'atm' => PhosphorIconsRegular.creditCard,
    'recovery' => PhosphorIconsRegular.wifiHigh,
    'blackspot' => PhosphorIconsRegular.warning,
    'destination' => PhosphorIconsRegular.mapPin,
    'origin' => PhosphorIconsRegular.navigationArrow,
    _ => PhosphorIconsRegular.mapPin,
  };
}

String operatorLabel(String id) => switch (id) {
      'jio' => 'Jio',
      'airtel' => 'Airtel',
      'vi' => 'Vi',
      'bsnl' => 'BSNL',
      _ => 'All networks',
    };

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

// ---------------------------------------------------------------------------
// Animated fade+slide entrance wrapper
// ---------------------------------------------------------------------------

extension AnimateIn on Widget {
  Widget fadeSlideIn({int delayMs = 0, int durationMs = 320}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: Duration(milliseconds: durationMs), curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: Duration(milliseconds: durationMs + 40),
          curve: Curves.easeOut,
        );
  }
}
