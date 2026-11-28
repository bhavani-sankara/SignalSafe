import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../core/geo.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';

/// A small, still piece of the real map fitted to [route], with the route
/// drawn on top and its weak/no-signal stretches in amber. Not interactive,
/// so it only loads a handful of tiles once and taps fall through to the
/// card underneath.
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({
    super.key,
    required this.route,
    required this.op,
    this.height = 150,
  });

  final JourneyRoute route;
  final String op;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final slices = splitByWeight(
      route.points,
      route.segments.map((s) => s.km).toList(),
    );
    bool low(int i) {
      final l = route.segments[i].levelFor(op);
      return l == 'none' || l == 'weak';
    }

    return SizedBox(
      height: height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: route.points,
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 20),
              ),
              backgroundColor: const Color(0xFFF2EFE9),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.signalsafe.app',
                keepBuffer: 0,
                panBuffer: 0,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.points,
                    color: Colors.white,
                    strokeWidth: 8,
                  ),
                  for (var i = 0; i < slices.length; i++)
                    if (slices[i].length > 1)
                      Polyline(
                        points: slices[i],
                        color: low(i) ? pal.moderate : pal.route,
                        strokeWidth: 4.5,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: route.points.first,
                    width: 16,
                    height: 16,
                    child: _dot(pal.beacon),
                  ),
                  Marker(
                    point: route.points.last,
                    width: 28,
                    height: 32,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      PhosphorIconsFill.mapPin,
                      size: 28,
                      color: pal.destination,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );
}

