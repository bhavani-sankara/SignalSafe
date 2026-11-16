import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_theme.dart';

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

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Material(
      color: color ?? pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: pal.border.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

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
    canvas.drawRect(
      bounds,
      Paint()..color = dark ? palette.ink : const Color(0xFFF2EFE9),
    );

    final park = Path()
      ..moveTo(size.width * 0.48, size.height * 0.26)
      ..lineTo(size.width * 0.88, size.height * 0.31)
      ..lineTo(size.width * 0.91, size.height * 0.88)
      ..lineTo(size.width * 0.43, size.height * 0.92)
      ..close();
    canvas.drawPath(
      park,
      Paint()..color = dark ? palette.elevated : const Color(0xFFCBE7CF),
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final road = Path()
      ..moveTo(-size.width * 0.05, size.height * 0.68)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.44,
        size.width * 0.62,
        size.height * 1.04,
        size.width * 1.05,
        size.height * 0.56,
      );
    canvas.drawPath(road, roadPaint);
    final sideRoad = Path()
      ..moveTo(size.width * 0.18, -size.height * 0.1)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.34,
        size.width * 0.12,
        size.height * 0.76,
        size.width * 0.2,
        size.height * 1.1,
      );
    canvas.drawPath(sideRoad, roadPaint);

    final route = Path()
      ..moveTo(size.width * 0.24, size.height * 0.18)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.52,
        size.width * 0.61,
        size.height * 0.8,
        size.width * 0.83,
        size.height * 0.58,
      );
    final routeCasing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routeCasing);
    final routePaint = Paint()
      ..color = palette.route
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, routePaint);
    final metrics = route.computeMetrics();
    for (final metric in metrics) {
      for (var i = 4; i <= 8; i++) {
        final point = metric
            .getTangentForOffset(metric.length * i / 12)
            ?.position;
        if (point != null) {
          canvas.drawCircle(point, 4, Paint()..color = palette.moderate);
        }
      }
    }

    final origin = Offset(size.width * 0.24, size.height * 0.18);
    canvas.drawCircle(
      origin,
      11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      origin,
      11,
      Paint()
        ..color = palette.beacon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final destination = Offset(size.width * 0.83, size.height * 0.58);
    canvas.drawCircle(destination, 13, Paint()..color = palette.destination);
    canvas.drawCircle(destination, 5, Paint()..color = Colors.white);

    if (dark) {
      canvas.drawRect(
        bounds,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_RoutePreviewPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

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
    final text =
        label ??
        switch (level) {
          'good' => 'Good',
          'moderate' => 'Moderate',
          'weak' => 'Weak',
          _ => 'No signal',
        };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: background),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
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
        width: 24,
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(
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
        letterSpacing: 0.2,
        color: pal.muted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.sos = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = sos
        ? pal.sos
        : selected
        ? pal.secondaryContainer
        : pal.surface;
    final fg = sos || selected
        ? (sos ? Colors.white : pal.onSecondaryContainer)
        : pal.text;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bg,
        elevation: selected || sos ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}

/// iOS grouped-list header: small uppercase grey label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 7),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w400,
          color: context.palette.muted,
        ),
      ),
    );
  }
}

/// Content section title, iOS style: bold title-case heading.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 20,
              letterSpacing: -0.4,
              color: context.palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
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

IconData categoryIcon(String category) {
  return switch (category) {
    'hospital' => PhosphorIconsRegular.heartbeat,
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
  return '${h}h ${m}m';
}
