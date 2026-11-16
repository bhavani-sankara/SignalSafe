import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/geo.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';

/// A small, offline-drawn map of a route: the real route geometry, coloured
/// segment by segment with its estimated signal, over a quiet map texture.
/// Used on trip cards and as the hero on trip details.
class RouteMiniMap extends StatelessWidget {
  const RouteMiniMap({
    super.key,
    required this.route,
    this.context = const [],
    this.operator = 'all',
    this.height = 140,
    this.padding = const EdgeInsets.fromLTRB(28, 22, 28, 22),
  });

  final JourneyRoute route;

  /// Other routes drawn faintly for orientation.
  final List<JourneyRoute> context;
  final String operator;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext buildContext) {
    final pal = buildContext.palette;
    final dark = Theme.of(buildContext).brightness == Brightness.dark;
    return Semantics(
      label: 'Map preview of ${route.name}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Quiet placeholder texture, visible while tiles load or offline.
              CustomPaint(
                painter: _MiniMapPainter(
                  route: route,
                  others: const [],
                  operator: operator,
                  pal: pal,
                  dark: dark,
                  padding: padding,
                  drawRoutes: false,
                ),
              ),
              IgnorePointer(child: _osm(pal, dark)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on RouteMiniMap {
  /// Live OpenStreetMap preview, fitted to the route and its alternatives.
  Widget _osm(SignalPalette pal, bool dark) {
    final others = context.where((r) => r.id != route.id).toList();
    final all = [...route.points, for (final r in others) ...r.points];
    if (route.points.length < 2) return const SizedBox.shrink();
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    final casing = dark ? const Color(0xFF0E1412) : Colors.white;
    return FlutterMap(
      key: ValueKey('${route.id}-$operator-$dark'),
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(all),
          padding: padding,
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
        backgroundColor: Colors.transparent,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.signalsafe.app',
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        PolylineLayer(
          polylines: [
            for (final other in others)
              if (other.points.length > 1)
                Polyline(
                  points: other.points,
                  color: pal.outline.withValues(alpha: 0.55),
                  strokeWidth: 3,
                ),
            Polyline(points: route.points, color: casing, strokeWidth: 8),
            for (var i = 0; i < slices.length && i < route.segments.length; i++)
              if (slices[i].length > 1)
                Polyline(
                  points: slices[i],
                  color: pal.levelFill(route.segments[i].levelFor(operator)),
                  strokeWidth: 5,
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: route.points.first,
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: pal.beacon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            Marker(
              point: route.points.last,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: pal.destination,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.route,
    required this.others,
    required this.operator,
    required this.pal,
    required this.dark,
    required this.padding,
    this.drawRoutes = true,
  });

  final bool drawRoutes;
  final JourneyRoute route;
  final List<JourneyRoute> others;
  final String operator;
  final SignalPalette pal;
  final bool dark;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final land = dark ? const Color(0xFF1B2421) : const Color(0xFFF1F3EF);
    final land2 = dark ? const Color(0xFF202B28) : const Color(0xFFE6EDE6);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [land, land2],
        ).createShader(rect),
    );

    // Quiet "map" texture: a few soft blocks and minor roads.
    final rnd = math.Random(route.id.hashCode);
    final block = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF7FB28A)).withValues(
        alpha: dark ? 0.03 : 0.12,
      );
    for (var i = 0; i < 5; i++) {
      final w = size.width * (0.18 + rnd.nextDouble() * 0.22);
      final h = size.height * (0.2 + rnd.nextDouble() * 0.3);
      final x = rnd.nextDouble() * (size.width - w);
      final y = rnd.nextDouble() * (size.height - h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(18),
        ),
        block,
      );
    }
    final minor = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final p = Path()
        ..moveTo(-10, size.height * rnd.nextDouble())
        ..quadraticBezierTo(
          size.width * rnd.nextDouble(),
          size.height * rnd.nextDouble(),
          size.width + 10,
          size.height * rnd.nextDouble(),
        );
      canvas.drawPath(p, minor);
    }

    if (!drawRoutes) return;

    // Projection fitted to all routes so alternatives stay in frame.
    final all = [route, ...others].expand((r) => r.points).toList();
    if (all.length < 2) return;
    var minLat = all.first.latitude, maxLat = minLat;
    var minLng = all.first.longitude, maxLng = minLng;
    for (final p in all) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * k, 1e-6);
    final spanY = math.max(maxLat - minLat, 1e-6);
    final inner = padding.deflateRect(rect);
    final scale = math.min(inner.width / spanX, inner.height / spanY);
    final offX = inner.left + (inner.width - spanX * scale) / 2;
    final offY = inner.top + (inner.height - spanY * scale) / 2;
    Offset project(LatLng p) => Offset(
      offX + (p.longitude - minLng) * k * scale,
      offY + (maxLat - p.latitude) * scale,
    );
    Path pathOf(List<LatLng> pts) {
      final path = Path()..moveTo(project(pts.first).dx, project(pts.first).dy);
      for (final p in pts.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      return path;
    }

    for (final other in others) {
      if (other.points.length < 2) continue;
      canvas.drawPath(
        pathOf(other.points),
        Paint()
          ..color = pal.outline.withValues(alpha: dark ? 0.45 : 0.35)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (route.points.length < 2) return;
    final full = pathOf(route.points);
    canvas.drawPath(
      full,
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.4 : 0.14)
        ..strokeWidth = 11
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      full,
      Paint()
        ..color = dark ? const Color(0xFF0E1412) : Colors.white
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    for (var i = 0; i < slices.length && i < route.segments.length; i++) {
      if (slices[i].length < 2) continue;
      final level = route.segments[i].levelFor(operator);
      final color = pal.levelFill(level);
      canvas.drawPath(
        pathOf(slices[i]),
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final a = project(route.points.first);
    final b = project(route.points.last);
    canvas.drawCircle(a, 8, Paint()..color = Colors.white);
    canvas.drawCircle(a, 5.5, Paint()..color = pal.beacon);
    canvas.drawCircle(
      b + const Offset(0, 1.5),
      9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(b, 9, Paint()..color = pal.destination);
    canvas.drawCircle(b, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.route.id != route.id ||
      old.operator != operator ||
      old.dark != dark ||
      old.others.length != others.length;
}
