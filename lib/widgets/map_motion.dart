import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/motion.dart';

/// Glides a flutter_map camera instead of jumping it. flutter_map only knows
/// `move()`, so this tweens the centre and zoom and calls `move()` every
/// frame.
class MapCameraAnimator {
  MapCameraAnimator({required this.map, required TickerProvider vsync})
    : _ctrl = AnimationController(vsync: vsync);

  final MapController map;
  final AnimationController _ctrl;
  VoidCallback? _tick;

  bool get isAnimating => _ctrl.isAnimating;

  void dispose() => _ctrl.dispose();

  void stop() => _ctrl.stop();

  /// Smoothly moves to [center] / [zoom].
  Future<void> moveTo(
    LatLng center,
    double zoom, {
    Duration duration = Motion.recenter,
    Curve curve = Motion.travel,
    double? rotation,
  }) {
    final MapCamera from;
    try {
      from = map.camera;
    } catch (_) {
      return Future.value(); // map not laid out yet
    }
    if (duration == Duration.zero) {
      map.moveAndRotate(center, zoom, rotation ?? from.rotation);
      return Future.value();
    }
    final lat = Tween(begin: from.center.latitude, end: center.latitude);
    final lng = Tween(begin: from.center.longitude, end: center.longitude);
    final z = Tween(begin: from.zoom, end: zoom);
    final rot = Tween(begin: from.rotation, end: rotation ?? from.rotation);
    final curved = CurvedAnimation(parent: _ctrl, curve: curve);

    if (_tick != null) _ctrl.removeListener(_tick!);
    _tick = () {
      final t = curved.value;
      map.moveAndRotate(
        LatLng(lat.transform(t), lng.transform(t)),
        z.transform(t),
        rot.transform(t),
      );
    };
    _ctrl
      ..stop()
      ..duration = duration
      ..addListener(_tick!);
    return _ctrl.forward(from: 0).orCancel.catchError((_) {});
  }

  /// Smoothly fits [bounds] inside the visible area left by [padding].
  Future<void> fitBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(48),
    Duration duration = Motion.camera,
    double maxZoom = 15,
  }) {
    final MapCamera target;
    try {
      target = CameraFit.bounds(
        bounds: bounds,
        padding: padding,
        maxZoom: maxZoom,
      ).fit(map.camera);
    } catch (_) {
      return Future.value();
    }
    return moveTo(
      target.center,
      target.zoom,
      duration: duration,
      rotation: 0,
    );
  }
}

/// The first [t] (0–1) of a polyline, measured by point count with the last
/// point interpolated, so a route can "draw itself" along the road.
List<LatLng> trimPolyline(List<LatLng> points, double t) {
  if (t >= 1 || points.length < 2) return points;
  if (t <= 0) return [points.first, points.first];
  final scaled = t * (points.length - 1);
  final i = scaled.floor();
  final f = scaled - i;
  final a = points[i];
  final b = points[(i + 1).clamp(0, points.length - 1)];
  return [
    ...points.take(i + 1),
    LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    ),
  ];
}
