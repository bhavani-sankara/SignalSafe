import 'package:flutter/widgets.dart';

/// Every timing and curve in the app lives here, so motion stays consistent
/// and is easy to tune in one place.
///
/// The numbers come from a frame-by-frame study of a modern maps app:
/// things never pop in without a fade, the map camera never hard-cuts, sheets
/// are physics-driven, and only one or two things move at a time.
abstract final class Motion {
  // ── Durations ───────────────────────────────────────────────────────────
  /// Chip/selection changes, tab cross-fades.
  static const quick = Duration(milliseconds: 200);

  /// Page fades (search opening), small layout changes.
  static const standard = Duration(milliseconds: 260);

  /// Modal sheets: scrim first, then the sheet.
  static const modal = Duration(milliseconds: 380);

  /// Camera fitting a route after "Directions".
  static const camera = Duration(milliseconds: 650);

  /// Route line drawing itself in.
  static const routeDraw = Duration(milliseconds: 550);

  /// Light → dark switch and the 3D tilt when navigation starts.
  static const cinematic = Duration(milliseconds: 900);

  /// Re-center / zoom-to-me: slow, soft tail.
  static const recenter = Duration(milliseconds: 1100);

  // ── Staging for the directions reveal ──────────────────────────────────
  /// Sheet shows skeletons immediately, the camera starts, then routes draw,
  /// then the time/signal bubbles pop in last.
  static const routeDrawDelay = Duration(milliseconds: 380);
  static const bubbleDelay = Duration(milliseconds: 900);
  static const bubbleStagger = Duration(milliseconds: 90);
  static const skeletonHold = Duration(milliseconds: 750);

  // ── Curves ──────────────────────────────────────────────────────────────
  /// Things arriving: fast start, long soft settle.
  static const enter = Curves.easeOutCubic;

  /// Things leaving.
  static const exit = Curves.easeInCubic;

  /// Camera moves and cinematic changes.
  static const travel = Curves.easeInOutCubic;

  // ── Springs ─────────────────────────────────────────────────────────────
  /// Critically damped (no bounce) spring used by every bottom sheet.
  /// Settles in roughly 400–450 ms and carries the finger's velocity.
  static final sheetSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 1.0,
  );

  /// True when the person asked the OS to reduce motion. Animations should
  /// then jump straight to their end state.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
