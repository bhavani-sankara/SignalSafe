import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

final catalogProvider = FutureProvider<Catalog>((ref) async {
  final raw = await rootBundle.loadString('assets/mock/catalog.json');
  return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

class Session {
  Session({
    required this.catalog,
    required this.operatorFilter,
    required this.overlayOn,
    required this.communityLayerOn,
    required this.originId,
    required this.destinationId,
    required this.selectedRouteId,
    required this.travelMode,
    required this.routePref,
    required this.safetyPref,
    required this.preferredOperator,
    required this.contacts,
    required this.trips,
    required this.recents,
    required this.reports,
    required this.flaggedIds,
    required this.simulateLoss,
    required this.simulateBlackspot,
    required this.voiceOn,
    required this.navActive,
    required this.navProgress,
    required this.darkMode,
    required this.notify,
    required this.userName,
    required this.queuedSos,
    required this.deviated,
  });

  final Catalog catalog;
  final String operatorFilter;
  final bool overlayOn;
  final bool communityLayerOn;
  final String originId;
  final String destinationId;
  final String selectedRouteId;
  final String travelMode;
  final String routePref;
  final String safetyPref;
  final String preferredOperator;
  final List<EmergencyContact> contacts;
  final List<SavedTrip> trips;
  final List<String> recents;
  final List<SignalReport> reports;
  final Set<String> flaggedIds;
  final bool simulateLoss;
  final bool simulateBlackspot;
  final bool voiceOn;
  final bool navActive;
  final double navProgress;
  final bool darkMode;
  final NotifyPrefs notify;
  final String userName;
  final bool queuedSos;
  final bool deviated;

  LatLng get here => catalog.currentLocation;
  Place get origin => catalog.place(originId);
  Place get destination => catalog.place(destinationId);
  JourneyRoute get route => catalog.routeById(selectedRouteId);

  List<JourneyRoute> rankedRoutes() {
    final list = [...catalog.routes];
    int score(JourneyRoute r) {
      if (routePref == 'fastest') return -r.durationMin;
      if (routePref == 'balanced') {
        return r.connectivityScore * 2 - (r.durationMin ~/ 10);
      }
      var s = r.connectivityScore;
      if (safetyPref == 'avoidBlackspots') {
        s -= r.stats[operatorFilter]?['none'] ?? r.stats['all']!['none']!;
      }
      if (safetyPref == 'nearServices') s += 4;
      return s;
    }

    list.sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  String currentSegmentLevel() {
    final segs = route.segments;
    if (simulateLoss || simulateBlackspot) return 'none';
    final i = (navProgress * segs.length).floor().clamp(0, segs.length - 1);
    return segs[i].levelFor(operatorFilter);
  }

  Session copyWith({
    String? operatorFilter,
    bool? overlayOn,
    bool? communityLayerOn,
    String? originId,
    String? destinationId,
    String? selectedRouteId,
    String? travelMode,
    String? routePref,
    String? safetyPref,
    String? preferredOperator,
    List<EmergencyContact>? contacts,
    List<SavedTrip>? trips,
    List<String>? recents,
    List<SignalReport>? reports,
    Set<String>? flaggedIds,
    bool? simulateLoss,
    bool? simulateBlackspot,
    bool? voiceOn,
    bool? navActive,
    double? navProgress,
    bool? darkMode,
    NotifyPrefs? notify,
    String? userName,
    bool? queuedSos,
    bool? deviated,
  }) {
    return Session(
      catalog: catalog,
      operatorFilter: operatorFilter ?? this.operatorFilter,
      overlayOn: overlayOn ?? this.overlayOn,
      communityLayerOn: communityLayerOn ?? this.communityLayerOn,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      selectedRouteId: selectedRouteId ?? this.selectedRouteId,
      travelMode: travelMode ?? this.travelMode,
      routePref: routePref ?? this.routePref,
      safetyPref: safetyPref ?? this.safetyPref,
      preferredOperator: preferredOperator ?? this.preferredOperator,
      contacts: contacts ?? this.contacts,
      trips: trips ?? this.trips,
      recents: recents ?? this.recents,
      reports: reports ?? this.reports,
      flaggedIds: flaggedIds ?? this.flaggedIds,
      simulateLoss: simulateLoss ?? this.simulateLoss,
      simulateBlackspot: simulateBlackspot ?? this.simulateBlackspot,
      voiceOn: voiceOn ?? this.voiceOn,
      navActive: navActive ?? this.navActive,
      navProgress: navProgress ?? this.navProgress,
      darkMode: darkMode ?? this.darkMode,
      notify: notify ?? this.notify,
      userName: userName ?? this.userName,
      queuedSos: queuedSos ?? this.queuedSos,
      deviated: deviated ?? this.deviated,
    );
  }
}

class SessionController extends Notifier<Session?> {
  @override
  Session? build() {
    final cat = ref.watch(catalogProvider);
    return cat.maybeWhen(
      data: (c) => Session(
        catalog: c,
        operatorFilter: 'all',
        overlayOn: true,
        communityLayerOn: true,
        originId: 'gachibowli',
        destinationId: 'srisailam',
        selectedRouteId: 'nh765',
        travelMode: 'car',
        routePref: 'connectivity',
        safetyPref: 'avoidBlackspots',
        preferredOperator: c.preferredOperator,
        contacts: [
          EmergencyContact(
            id: 'c1',
            name: 'Meera Reddy',
            phone: '+91 98490 11223',
            preferred: true,
          ),
          EmergencyContact(
            id: 'c2',
            name: 'Hyderabad Traffic Helpline',
            phone: '103',
            preferred: false,
          ),
        ],
        trips: [
          SavedTrip(
            id: 't1',
            name: 'Hyderabad to Srisailam – Weekend Trip',
            routeId: 'nh765',
            originId: 'gachibowli',
            destinationId: 'srisailam',
            offlinePrepared: true,
            kind: 'saved',
          ),
          SavedTrip(
            id: 't2',
            name: 'HITEC City',
            routeId: 'nh765',
            originId: 'gachibowli',
            destinationId: 'hitech',
            offlinePrepared: false,
            kind: 'recent',
          ),
        ],
        recents: ['Srisailam', 'Hospitals near NH765', 'Mannanur recovery'],
        reports: c.reports,
        flaggedIds: {},
        simulateLoss: false,
        simulateBlackspot: false,
        voiceOn: false,
        navActive: false,
        navProgress: 0.18,
        darkMode: false,
        notify: const NotifyPrefs(),
        userName: c.userName,
        queuedSos: false,
        deviated: false,
      ),
      orElse: () => null,
    );
  }

  void update(Session Function(Session s) fn) {
    final cur = state;
    if (cur == null) return;
    state = fn(cur);
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(
  SessionController.new,
);
