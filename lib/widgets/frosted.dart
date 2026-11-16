import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme/app_theme.dart';
import 'hud.dart';

/// Shared motion language. Every animated surface in the app should pull its
/// timing from here so transitions feel like one system.
abstract final class Motion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 280);
  static const emphasized = Duration(milliseconds: 420);

  /// Material 3 "emphasized decelerate": fast start, gentle settle.
  static const enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 "emphasized accelerate" for elements leaving.
  static const exit = Cubic(0.3, 0.0, 0.8, 0.15);

  static const settle = Curves.easeOutCubic;
}

/// Elevation recipe for floating map chrome: a soft ambient shadow plus a
/// tighter key shadow, which reads as "lifted" without a hard edge.
List<BoxShadow> floatShadow(BuildContext context, {double lift = 1}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final a = dark ? 0.42 : 0.10;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: a * lift),
      blurRadius: 24 * lift,
      offset: Offset(0, 8 * lift),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: a * 0.8),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

/// A translucent, background-blurring surface used for anything that floats
/// over the map or over scrolling content: the search pill, chips, the
/// journey sheet and the navigation bar.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding = EdgeInsets.zero,
    this.opacity,
    this.blur = 24,
    this.shadow = true,
    this.lift = 1,
    this.tint,
    this.border = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double? opacity;
  final double blur;
  final bool shadow;
  final double lift;
  final Color? tint;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? pal.surface;
    final alpha = opacity ?? (dark ? 0.78 : 0.82);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ? floatShadow(context, lift: lift) : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base.withValues(alpha: alpha),
              borderRadius: borderRadius,
              border: border
                  ? Border.all(
                      color: (dark ? Colors.white : Colors.black).withValues(
                        alpha: dark ? 0.08 : 0.06,
                      ),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a tappable surface so it dips slightly while pressed, which makes
/// cards and pills feel physical.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.quick,
        curve: Motion.settle,
        child: widget.child,
      ),
    );
  }
}

/// Drag handle used at the top of every sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: context.palette.outline.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Coverage strip: proportional good/moderate/weak/none bar.
class CoverageStrip extends StatelessWidget {
  const CoverageStrip({super.key, required this.stats, this.height = 8});

  final Map<String, int> stats;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      label:
          'Estimated coverage: ${stats['good'] ?? 0}% good, ${stats['moderate'] ?? 0}% moderate, '
          '${stats['weak'] ?? 0}% weak, ${stats['none'] ?? 0}% no signal',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (final level in const ['good', 'moderate', 'weak', 'none'])
                  if ((stats[level] ?? 0) > 0)
                    Expanded(
                      flex: stats[level]!,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        color: pal.levelFill(level),
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

/// One stop on a route's signal timeline.
class SegmentRow extends StatelessWidget {
  const SegmentRow({
    super.key,
    required this.segment,
    required this.level,
    required this.first,
    required this.last,
  });

  final RouteSegment segment;
  final String level;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final color = pal.levelFill(level);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 3,
                      color: first ? Colors.transparent : pal.border,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.surface, width: 2),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 3,
                      color: last ? Colors.transparent : pal.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      segment.label,
                      style: TextStyle(
                        color: pal.text,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${segment.km.toStringAsFixed(0)} km · ${formatDuration(segment.min)}',
                      style: TextStyle(color: pal.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
            Center(child: SignalChip(level: level, compact: true)),
          ],
        ),
      ),
    );
  }
}
