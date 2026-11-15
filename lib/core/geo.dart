import 'package:latlong2/latlong.dart';

import 'models.dart';

const distance = Distance();

LatLng pointAlong(List<LatLng> points, double t) {
  if (points.isEmpty) return const LatLng(0, 0);
  if (points.length == 1) return points.first;
  final clamped = t.clamp(0.0, 1.0);
  final scaled = clamped * (points.length - 1);
  final index = scaled.floor().clamp(0, points.length - 2);
  final local = scaled - index;
  final a = points[index];
  final b = points[index + 1];
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * local,
    a.longitude + (b.longitude - a.longitude) * local,
  );
}

List<List<LatLng>> splitByWeight(List<LatLng> points, List<double> weights) {
  if (points.length < 2 || weights.isEmpty) return [points];
  final total = weights.fold<double>(0, (sum, w) => sum + w);
  if (total <= 0) return [points];
  final slices = <List<LatLng>>[];
  var start = 0;
  for (var i = 0; i < weights.length; i++) {
    final isLast = i == weights.length - 1;
    var end = isLast
        ? points.length - 1
        : (start + (weights[i] / total) * (points.length - 1)).round();
    end = end.clamp(start + 1, points.length - 1);
    slices.add(points.sublist(start, end + 1));
    start = end;
  }
  return slices;
}

int segmentIndex(JourneyRoute route, double progress) {
  if (route.segments.isEmpty) return 0;
  return (progress * route.segments.length)
      .floor()
      .clamp(0, route.segments.length - 1);
}

RouteSegment? nextGap(JourneyRoute route, String operator, double progress) {
  final start = segmentIndex(route, progress);
  for (var i = start; i < route.segments.length; i++) {
    final level = route.segments[i].levelFor(operator);
    if (level == 'none' || level == 'weak') return route.segments[i];
  }
  return null;
}

Place? nextRecovery(List<Place> places, LatLng here, LatLng destination) {
  final recoveries = places.where((p) => p.category == 'recovery').toList();
  if (recoveries.isEmpty) return null;
  final remaining = distance(here, destination);
  final ahead = recoveries.where((p) {
    return distance(p.point, destination) < remaining - 400;
  }).toList();
  final pool = ahead.isEmpty ? recoveries : ahead;
  pool.sort(
    (a, b) => distance(here, a.point).compareTo(distance(here, b.point)),
  );
  return pool.first;
}

String agoLabel(int minutes) {
  if (minutes < 60) return '$minutes min ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  return '${hours ~/ 24}d ago';
}
