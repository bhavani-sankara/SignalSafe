import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// The three resting heights of a [SpringSheet].
enum SheetDetent { peek, half, full }

/// Drives a [SpringSheet]: lets the screen snap it to a detent and listen to
/// its height (for fading the search bar, moving map buttons, and so on).
class SpringSheetController extends ChangeNotifier {
  _SpringSheetState? _state;

  /// Current visible height of the sheet, in logical pixels.
  double get height => _state?._height ?? 0;

  /// 0 at the half detent, 1 at full. Used to fade chrome out as the sheet
  /// takes over the screen.
  double get expansion => _state?._expansion ?? 0;

  /// 0 at peek, 1 at half.
  double get lift => _state?._lift ?? 0;

  SheetDetent get detent => _state?._detent ?? SheetDetent.half;

  bool get isAttached => _state != null;

  void snapTo(SheetDetent detent, {double velocity = 0}) =>
      _state?._settle(detent, velocity: velocity);

  void _notify() => notifyListeners();
}

/// A bottom sheet with three detents (peek / half / full) that follows the
/// finger, keeps the fling velocity, and settles with a critically damped
/// spring so it never overshoots.
///
/// The sheet owns the vertical drag. While it's at full height and its
/// content is scrolled, drags scroll the content instead; pulling down from
/// the top of the content drags the sheet down again. One gesture, no
/// hand-off glitches.
class SpringSheet extends StatefulWidget {
  const SpringSheet({
    super.key,
    required this.controller,
    required this.peekHeight,
    required this.halfFraction,
    required this.builder,
    this.initialDetent = SheetDetent.half,
    this.header,
    this.onDetentChanged,
  });

  final SpringSheetController controller;

  /// Height of the peek detent above the bottom clearance (nav bar).
  final double peekHeight;

  /// Half detent as a fraction of the available height.
  final double halfFraction;

  final SheetDetent initialDetent;

  /// Pinned at the top of the sheet (handle + title). Not part of the scroll.
  final Widget? header;

  /// Scrollable content. Must use the given controller and physics.
  final Widget Function(
    BuildContext context,
    ScrollController scrollController,
    ScrollPhysics physics,
  )
  builder;

  final ValueChanged<SheetDetent>? onDetentChanged;

  @override
  State<SpringSheet> createState() => _SpringSheetState();
}

class _SpringSheetState extends State<SpringSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onTick);
  final _scroll = ScrollController();

  double _bottomClearance = 0;
  double _available = 0; // room between status bar and screen bottom
  double _height = 0;
  SheetDetent _detent = SheetDetent.half;
  bool _initialised = false;
  bool _dragScrollsContent = false;

  double get _peek => _bottomClearance + widget.peekHeight;
  double get _half =>
      math.max(_peek + 80, _available * widget.halfFraction + _bottomClearance);
  double get _full => _available;

  double _px(SheetDetent d) => switch (d) {
    SheetDetent.peek => _peek,
    SheetDetent.half => _half,
    SheetDetent.full => _full,
  };

  double get _expansion =>
      ((_height - _half) / math.max(1, _full - _half)).clamp(0.0, 1.0);
  double get _lift =>
      ((_height - _peek) / math.max(1, _half - _peek)).clamp(0.0, 1.0);

  bool get _atFull => _height >= _full - 0.5;

  @override
  void initState() {
    super.initState();
    _detent = widget.initialDetent;
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(SpringSheet old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() => _height = _anim.value);
    widget.controller._notify();
  }

  void _setHeight(double h) {
    _anim.stop();
    _anim.value = h; // triggers _onTick
  }

  // ── Settling ────────────────────────────────────────────────────────────

  void _settle(SheetDetent target, {double velocity = 0}) {
    if (!_initialised) {
      _detent = target;
      return;
    }
    final changed = target != _detent;
    _detent = target;
    if (target != SheetDetent.full && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    if (changed) widget.onDetentChanged?.call(target);
    if (Motion.reduced(context)) {
      _setHeight(_px(target));
      return;
    }
    final sim = SpringSimulation(
      Motion.sheetSpring,
      _height,
      _px(target),
      velocity,
    )..tolerance = const Tolerance(distance: 0.5, velocity: 5);
    _anim.animateWith(sim);
  }

  SheetDetent _targetFor(double velocity) {
    // velocity: positive = sheet growing (finger moving up).
    const flick = 700.0;
    final order = SheetDetent.values;
    if (velocity.abs() > flick) {
      // A real flick moves one detent in its direction from where we are.
      final above = order.where((d) => _px(d) > _height + 1).toList();
      final below = order.where((d) => _px(d) < _height - 1).toList();
      if (velocity > 0 && above.isNotEmpty) return above.first;
      if (velocity < 0 && below.isNotEmpty) return below.last;
    }
    // Otherwise project a little forward and pick the nearest detent.
    final projected = _height + velocity * 0.12;
    return order.reduce(
      (a, b) =>
          (_px(a) - projected).abs() <= (_px(b) - projected).abs() ? a : b,
    );
  }

  // ── Gestures ────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) {
    _anim.stop();
    _dragScrollsContent =
        _atFull && _scroll.hasClients && _scroll.offset > 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = d.primaryDelta ?? 0; // + = finger moving down
    if (_atFull && _scroll.hasClients) {
      final pos = _scroll.position;
      // Scrolling content: finger up while full, or content not at top.
      if (dy < 0 || pos.pixels > 0 || _dragScrollsContent) {
        final next = (pos.pixels - dy).clamp(0.0, pos.maxScrollExtent);
        if (next != pos.pixels || dy < 0) {
          pos.jumpTo(next);
          if (pos.pixels > 0) _dragScrollsContent = true;
          return;
        }
        _dragScrollsContent = false;
      }
    }
    var next = _height - dy;
    // Rubber-band past the ends instead of a hard stop.
    if (next > _full) next = _full + (next - _full) * 0.15;
    if (next < _peek) next = _peek - (_peek - next) * 0.35;
    _setHeight(next.clamp(_peek * 0.6, _full + 24));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = -(d.primaryVelocity ?? 0); // + = growing
    if (_dragScrollsContent && _scroll.hasClients) {
      _dragScrollsContent = false;
      final pos = _scroll.position;
      if (pos is ScrollPositionWithSingleContext) pos.goBallistic(-v);
      if (_height < _full) _settle(SheetDetent.full);
      return;
    }
    _settle(_targetFor(v), velocity: v);
  }

  void _cycle() {
    _settle(switch (_detent) {
      SheetDetent.peek => SheetDetent.half,
      SheetDetent.half => SheetDetent.full,
      SheetDetent.full => SheetDetent.half,
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final clearance = media.padding.bottom;
        final available = constraints.maxHeight - media.padding.top;
        final layoutChanged =
            clearance != _bottomClearance || available != _available;
        _bottomClearance = clearance;
        _available = available;
        if (!_initialised) {
          _initialised = true;
          _height = _px(_detent);
        } else if (layoutChanged && !_anim.isAnimating) {
          // Rotation or resize: stay on the same detent.
          _height = _px(_detent);
        }

        // Corners flatten as the sheet becomes the full screen.
        final radius = 28 * (1 - _expansion);

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: math.max(0, _height),
            width: double.infinity,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: (dark ? 0.4 : 0.12) * (1 - _expansion),
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: _bottomClearance),
                      child: Column(
                        children: [
                          // Status-bar spacer grows in as the sheet goes full.
                          SizedBox(height: media.padding.top * _expansion),
                          _Handle(onTap: _cycle, fade: _expansion),
                          ?widget.header,
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              removeBottom: true,
                              child: widget.builder(
                                context,
                                _scroll,
                                const NeverScrollableScrollPhysics(
                                  parent: ClampingScrollPhysics(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.onTap, required this.fade});

  final VoidCallback onTap;
  final double fade;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Resize sheet',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 22,
          width: double.infinity,
          child: Center(
            child: Opacity(
              opacity: 1 - fade * 0.6,
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
