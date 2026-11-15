import 'package:latlong2/latlong.dart';

class Place {
  Place({
    required this.id,
    required this.name,
    required this.category,
    required this.point,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String category;
  final LatLng point;
  final String subtitle;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        subtitle: json['subtitle'] as String? ?? '',
      );
}

class Tower {
  Tower({
    required this.id,
    required this.name,
    required this.operator,
    required this.tech,
    required this.point,
    required this.source,
    required this.detail,
  });

  final String id;
  final String name;
  final String operator;
  final String tech;
  final LatLng point;
  final String source;
  final String detail;

  factory Tower.fromJson(Map<String, dynamic> json) => Tower(
        id: json['id'] as String,
        name: json['name'] as String,
        operator: json['operator'] as String,
        tech: json['tech'] as String,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        source: json['source'] as String,
        detail: json['detail'] as String,
      );
}

class Blackspot {
  Blackspot({
    required this.id,
    required this.name,
    required this.lengthKm,
    required this.durationMin,
    required this.warning,
    required this.points,
  });

  final String id;
  final String name;
  final double lengthKm;
  final int durationMin;
  final String warning;
  final List<LatLng> points;

  factory Blackspot.fromJson(Map<String, dynamic> json) => Blackspot(
        id: json['id'] as String,
        name: json['name'] as String,
        lengthKm: (json['lengthKm'] as num).toDouble(),
        durationMin: json['durationMin'] as int,
        warning: json['warning'] as String,
        points: (json['points'] as List)
            .map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()))
            .toList(),
      );
}

class RouteSegment {
  RouteSegment({
    required this.label,
    required this.km,
    required this.min,
    required this.levels,
  });

  final String label;
  final double km;
  final int min;
  final Map<String, String> levels;

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
        label: json['label'] as String,
        km: (json['km'] as num).toDouble(),
        min: json['min'] as int,
        levels: (json['levels'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );

  String levelFor(String operator) => levels[operator] ?? levels['all'] ?? 'none';
}

class JourneyRoute {
  JourneyRoute({
    required this.id,
    required this.name,
    required this.via,
    required this.distanceKm,
    required this.durationMin,
    required this.connectivityScore,
    required this.recommended,
    required this.outlook,
    required this.points,
    required this.segments,
    required this.stats,
  });

  final String id;
  final String name;
  final String via;
  final double distanceKm;
  final int durationMin;
  final int connectivityScore;
  final bool recommended;
  final String outlook;
  final List<LatLng> points;
  final List<RouteSegment> segments;
  final Map<String, Map<String, int>> stats;

  factory JourneyRoute.fromJson(Map<String, dynamic> json) => JourneyRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        via: json['via'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        durationMin: json['durationMin'] as int,
        connectivityScore: json['connectivityScore'] as int,
        recommended: json['recommended'] as bool? ?? false,
        outlook: json['outlook'] as String,
        points: (json['points'] as List)
            .map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()))
            .toList(),
        segments: (json['segments'] as List)
            .map((e) => RouteSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: (json['stats'] as Map).map(
          (k, v) => MapEntry(
            k.toString(),
            (v as Map).map(
              (sk, sv) => MapEntry(sk.toString(), (sv as num).toInt()),
            ),
          ),
        ),
      );
}

class SignalReport {
  SignalReport({
    required this.id,
    required this.point,
    required this.level,
    required this.operator,
    required this.tech,
    required this.comment,
    required this.minutesAgo,
    required this.agreement,
  });

  final String id;
  final LatLng point;
  final String level;
  final String operator;
  final String tech;
  final String comment;
  final int minutesAgo;
  final double agreement;

  factory SignalReport.fromJson(Map<String, dynamic> json) => SignalReport(
        id: json['id'] as String,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        level: json['level'] as String,
        operator: json['operator'] as String,
        tech: json['tech'] as String,
        comment: json['comment'] as String? ?? '',
        minutesAgo: json['minutesAgo'] as int? ?? 0,
        agreement: (json['agreement'] as num?)?.toDouble() ?? 0.5,
      );

  SignalReport copyWith({int? minutesAgo}) => SignalReport(
        id: id,
        point: point,
        level: level,
        operator: operator,
        tech: tech,
        comment: comment,
        minutesAgo: minutesAgo ?? this.minutesAgo,
        agreement: agreement,
      );
}

class SafetyAlert {
  SafetyAlert({
    required this.id,
    required this.severity,
    required this.title,
    required this.body,
  });

  final String id;
  final String severity;
  final String title;
  final String body;

  factory SafetyAlert.fromJson(Map<String, dynamic> json) => SafetyAlert(
        id: json['id'] as String,
        severity: json['severity'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
      );
}

class Catalog {
  Catalog({
    required this.userName,
    required this.userHandle,
    required this.preferredOperator,
    required this.currentLocation,
    required this.places,
    required this.towers,
    required this.blackspots,
    required this.routes,
    required this.reports,
    required this.alerts,
    required this.instructions,
    required this.savedPlaces,
  });

  final String userName;
  final String userHandle;
  final String preferredOperator;
  final LatLng currentLocation;
  final List<Place> places;
  final List<Tower> towers;
  final List<Blackspot> blackspots;
  final List<JourneyRoute> routes;
  final List<SignalReport> reports;
  final List<SafetyAlert> alerts;
  final List<String> instructions;
  final List<Map<String, String>> savedPlaces;

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
        userName: json['user']['name'] as String,
        userHandle: json['user']['handle'] as String,
        preferredOperator: json['user']['preferredOperator'] as String,
        currentLocation: LatLng(
          (json['currentLocation'][0] as num).toDouble(),
          (json['currentLocation'][1] as num).toDouble(),
        ),
        places: (json['places'] as List)
            .map((e) => Place.fromJson(e as Map<String, dynamic>))
            .toList(),
        towers: (json['towers'] as List)
            .map((e) => Tower.fromJson(e as Map<String, dynamic>))
            .toList(),
        blackspots: (json['blackspots'] as List)
            .map((e) => Blackspot.fromJson(e as Map<String, dynamic>))
            .toList(),
        routes: (json['routes'] as List)
            .map((e) => JourneyRoute.fromJson(e as Map<String, dynamic>))
            .toList(),
        reports: (json['reports'] as List)
            .map((e) => SignalReport.fromJson(e as Map<String, dynamic>))
            .toList(),
        alerts: (json['alerts'] as List)
            .map((e) => SafetyAlert.fromJson(e as Map<String, dynamic>))
            .toList(),
        instructions: (json['instructions'] as List).cast<String>(),
        savedPlaces: (json['savedPlaces'] as List)
            .map((e) => {
                  'id': e['id'] as String,
                  'label': e['label'] as String,
                })
            .toList(),
      );

  Place place(String id) => places.firstWhere((p) => p.id == id);

  JourneyRoute routeById(String id) =>
      routes.firstWhere((r) => r.id == id, orElse: () => routes.first);
}

class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.preferred,
  });

  final String id;
  final String name;
  final String phone;
  final bool preferred;

  EmergencyContact copyWith({String? name, String? phone, bool? preferred}) =>
      EmergencyContact(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        preferred: preferred ?? this.preferred,
      );
}

class SavedTrip {
  SavedTrip({
    required this.id,
    required this.name,
    required this.routeId,
    required this.originId,
    required this.destinationId,
    required this.offlinePrepared,
    required this.kind,
  });

  final String id;
  final String name;
  final String routeId;
  final String originId;
  final String destinationId;
  final bool offlinePrepared;
  final String kind;

  SavedTrip copyWith({String? name, bool? offlinePrepared}) => SavedTrip(
        id: id,
        name: name ?? this.name,
        routeId: routeId,
        originId: originId,
        destinationId: destinationId,
        offlinePrepared: offlinePrepared ?? this.offlinePrepared,
        kind: kind,
      );
}

class NotifyPrefs {
  const NotifyPrefs({
    this.blackspots = true,
    this.lossRestore = true,
    this.recovery = true,
    this.safety = true,
  });

  final bool blackspots;
  final bool lossRestore;
  final bool recovery;
  final bool safety;

  NotifyPrefs copyWith({
    bool? blackspots,
    bool? lossRestore,
    bool? recovery,
    bool? safety,
  }) =>
      NotifyPrefs(
        blackspots: blackspots ?? this.blackspots,
        lossRestore: lossRestore ?? this.lossRestore,
        recovery: recovery ?? this.recovery,
        safety: safety ?? this.safety,
      );
}
