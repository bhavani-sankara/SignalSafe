import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hud.dart';
import '../../widgets/skeleton.dart';
import 'map_widgets.dart';

// ===========================================================================
// EXPLORE sheet (no route yet)
// ===========================================================================

class ExploreHeader extends StatelessWidget {
  const ExploreHeader({
    super.key,
    required this.session,
    required this.expansion,
    required this.onCollapse,
  });

  final Session session;
  final double expansion;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final area = session.origin.name.split(',').first;
    final level = session.route.segments.first.levelFor(
      session.preferredOperator,
    );
    final city = session.origin.name.contains(',')
        ? session.origin.name.split(',').last.trim()
        : 'Your area';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: pal.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$city · signal checked just now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: pal.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _AreaSignal(operator: session.preferredOperator, level: level),
          // Collapse control appears as the sheet becomes the full screen.
          AnimatedSize(
            duration: Motion.quick,
            curve: Motion.enter,
            child: expansion > 0.6
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      tooltip: 'Show map',
                      onPressed: onCollapse,
                      style: IconButton.styleFrom(
                        backgroundColor: pal.elevated,
                      ),
                      icon: const Icon(PhosphorIconsRegular.caretDown, size: 18),
                    ),
                  )
                : const SizedBox(width: 8),
          ),
        ],
      ),
    );
  }
}

class ExploreBody extends StatelessWidget {
  const ExploreBody({
    super.key,
    required this.session,
    required this.scroll,
    required this.physics,
    required this.onDirections,
    required this.onTripDetails,
    required this.onPlace,
    required this.onTower,
    required this.onReport,
    required this.onSeeCommunity,
  });

  final Session session;
  final ScrollController scroll;
  final ScrollPhysics physics;
  final VoidCallback onDirections;
  final VoidCallback onTripDetails;
  final ValueChanged<Place> onPlace;
  final ValueChanged<Tower> onTower;
  final ValueChanged<SignalReport> onReport;
  final VoidCallback onSeeCommunity;

  @override
  Widget build(BuildContext context) {
    final here = session.here;
    final towers = [...session.catalog.towers]
      ..sort(
        (a, b) => distance(here, a.point).compareTo(distance(here, b.point)),
      );
    final recoveries = session.catalog.places
        .where((p) => p.category == 'recovery')
        .toList();
    final essentials = session.catalog.places
        .where(
          (p) => const {
            'hospital',
            'police',
            'fuel',
            'hotel',
          }.contains(p.category),
        )
        .toList();
    final reports = session.reports
        .where((r) => !session.flaggedIds.contains(r.id))
        .take(3)
        .toList();

    return ListView(
      controller: scroll,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: _ContinueCard(
            session: session,
            onDirections: onDirections,
            onDetails: onTripDetails,
          ),
        ),
        const SheetSectionTitle(
          'Signal around you',
          subtitle: 'Nearest towers and where coverage comes back',
        ),
        _Carousel(
          height: 132,
          children: [
            for (final t in towers.take(4))
              _TowerCard(tower: t, km: distance(here, t.point) / 1000, onTap: () => onTower(t)),
            for (final p in recoveries.take(3))
              _PlaceCard(place: p, onTap: () => onPlace(p)),
          ],
        ),
        const SheetSectionTitle(
          'Essentials on the way',
          subtitle: 'Help points along NH 765',
        ),
        _Carousel(
          height: 132,
          children: [
            for (final p in essentials) _PlaceCard(place: p, onTap: () => onPlace(p)),
          ],
        ),
        const SheetSectionTitle('From the community'),
        for (final r in reports) _ReportRow(report: r, onTap: () => onReport(r)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SeeAllPill(label: 'See all reports', onTap: onSeeCommunity),
        ),
      ],
    );
  }
}

/// Quiet signal readout for the header: mini bars, network, strength.
class _AreaSignal extends StatelessWidget {
  const _AreaSignal({required this.operator, required this.level});

  final String operator;
  final String level;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final word = switch (level) {
      'good' => 'Strong',
      'moderate' => 'Fair',
      'weak' => 'Weak',
      _ => 'No signal',
    };
    return Semantics(
      label: '${operatorLabel(operator)} signal here: $word',
      child: ExcludeSemantics(
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
          decoration: BoxDecoration(
            color: pal.elevated,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: FittedBox(child: SignalBars(level: level)),
              ),
              const SizedBox(width: 6),
              Text(
                operatorLabel(operator),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pal.text,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                word,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pal.level(level),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.session,
    required this.onDirections,
    required this.onDetails,
  });

  final Session session;
  final VoidCallback onDirections;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final route = session.route;
    final low = lowSignalMinutes(route, session.operatorFilter);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: dark ? pal.secondaryContainer : const Color(0xFFF1F5FE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pal.beacon,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsFill.clockCounterClockwise,
                  size: 20,
                  color: dark ? pal.ink : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue your trip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pal.beacon,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${session.origin.name.split(',').first} to ${session.destination.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: pal.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatDuration(route.durationMin),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: pal.text,
                      ),
                    ),
                    TextSpan(
                      text: '  ·  ${route.distanceKm.toStringAsFixed(0)} km',
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 14, color: pal.muted),
              ),
              if (low > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsBold.cellSignalSlash,
                      size: 14,
                      color: pal.moderate,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$low min low signal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pal.moderate,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          SignalCoverageBar(
            stats: route.stats[session.operatorFilter] ?? route.stats['all']!,
            height: 8,
            showLegend: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(PhosphorIconsFill.arrowBendUpRight, size: 18),
                  label: const Text(
                    'Directions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  style: dark
                      ? null
                      : OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                  child: const Text(
                    'Trip details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal carousel whose cards are ~80% wide so the next one peeks in.
class _Carousel extends StatelessWidget {
  const _Carousel({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(280.0, 520.0);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: width * 0.62,
          child: children[i],
        ),
      ),
    );
  }
}

class _TintCard extends StatelessWidget {
  const _TintCard({
    required this.tint,
    required this.child,
    required this.onTap,
    required this.semantics,
  });

  final Color tint;
  final Widget child;
  final VoidCallback onTap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

class _TowerCard extends StatelessWidget {
  const _TowerCard({required this.tower, required this.km, required this.onTap});

  final Tower tower;
  final double km;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = operatorColor(tower.operator);
    return _TintCard(
      tint: dark
          ? Color.alphaBlend(c.withValues(alpha: 0.16), pal.elevated)
          : Color.alphaBlend(c.withValues(alpha: 0.08), Colors.white),
      onTap: onTap,
      semantics: '${operatorLabel(tower.operator)} tower, ${tower.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: const Icon(
                  PhosphorIconsFill.broadcast,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                tower.tech,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            tower.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: pal.text,
            ),
          ),
          const SizedBox(height: 2),
          MetaLine([
            operatorLabel(tower.operator),
            '${km.toStringAsFixed(km < 10 ? 1 : 0)} km',
          ]),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = categoryAccent(place.category, pal);
    return _TintCard(
      tint: categoryTint(place.category, dark),
      onTap: onTap,
      semantics: place.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIcon(place.category), size: 18, color: accent),
          ),
          const Spacer(),
          Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: pal.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            place.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: pal.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onTap});

  final SignalReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pal.levelContainer(report.level),
                shape: BoxShape.circle,
              ),
              child: Center(child: SignalBars(level: report.level)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.comment.isEmpty ? 'Signal report' : report.comment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MetaLine([
                    operatorLabel(report.operator),
                    report.tech,
                    agoLabel(report.minutesAgo),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// DIRECTIONS sheet
// ===========================================================================

class DirectionsHeader extends StatelessWidget {
  const DirectionsHeader({
    super.key,
    required this.session,
    required this.loading,
    required this.expansion,
    required this.onOperator,
    required this.onCollapse,
  });

  final Session session;
  final bool loading;
  final double expansion;
  final ValueChanged<String> onOperator;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final route = session.route;
    final op = session.operatorFilter;
    final low = lowSignalMinutes(route, op);
    final score = networkScore(route, op);
    // ETA in amber when there's a stretch with no signal, like traffic.
    final etaColor = low > 0 ? pal.moderate : pal.good;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.standard),
          switchInCurve: Motion.enter,
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 62,
                )
              : Padding(
                  key: ValueKey('eta-${route.id}-$op'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatDuration(route.durationMin),
                                  style: TextStyle(
                                    color: etaColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${route.distanceKm.toStringAsFixed(0)} km)',
                                  style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              route.recommended
                                  ? 'Best signal, even with the forest stretch'
                                  : 'via ${route.via}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: pal.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      _ScoreBadge(score: score),
                      AnimatedSize(
                        duration: Motion.quick,
                        child: expansion > 0.6
                            ? Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: IconButton(
                                  tooltip: 'Show map',
                                  onPressed: onCollapse,
                                  style: IconButton.styleFrom(
                                    backgroundColor: pal.elevated,
                                  ),
                                  icon: const Icon(
                                    PhosphorIconsRegular.caretDown,
                                    size: 18,
                                  ),
                                ),
                              )
                            : const SizedBox(width: 8),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 6),
        NetworkTabs(route: route, selected: op, onSelected: onOperator),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final c = scoreColor(pal, score);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Signal score $score',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            c.withValues(alpha: dark ? 0.22 : 0.13),
            pal.surface,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$score',
              style: TextStyle(
                color: c,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            Text(
              'signal',
              style: TextStyle(
                color: c,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DirectionsBody extends StatelessWidget {
  const DirectionsBody({
    super.key,
    required this.session,
    required this.scroll,
    required this.physics,
    required this.loading,
    required this.onStart,
    required this.onOffline,
    required this.onReport,
    required this.onCompare,
    required this.onShare,
    required this.onSelectRoute,
  });

  final Session session;
  final ScrollController scroll;
  final ScrollPhysics physics;
  final bool loading;
  final VoidCallback onStart;
  final VoidCallback onOffline;
  final VoidCallback onReport;
  final VoidCallback onCompare;
  final VoidCallback onShare;
  final ValueChanged<String> onSelectRoute;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.standard),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      child: loading
          ? ListView(
              key: const ValueKey('skeleton'),
              controller: scroll,
              physics: physics,
              children: const [
                SizedBox(height: 14),
                RouteSheetSkeleton(label: 'Finding the best-signal route…'),
              ],
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final pal = context.palette;
    final route = session.route;
    final op = session.operatorFilter;
    final lowSegs = route.segments.where((s) {
      final l = s.levelFor(op);
      return l == 'none' || l == 'weak';
    }).toList();
    final lowMin = lowSegs.fold<int>(0, (t, s) => t + s.min);
    final lowFrom = lowSegs.isEmpty ? null : lowSegs.first.label.split(' – ').first;
    final others = session.rankedRoutes().where((r) => r.id != route.id).toList();

    var i = 0;
    Widget stagger(Widget w) => w
        .animate(delay: (40 * i++).ms)
        .fadeIn(duration: 260.ms, curve: Motion.enter)
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Motion.enter);

    return ListView(
      key: ValueKey('content-${route.id}'),
      controller: scroll,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 14),
        stagger(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SignalCoverageBar(
              stats: route.stats[op] ?? route.stats['all']!,
              height: 8,
              showLabels: true,
            ),
          ),
        ),
        if (lowMin > 0)
          stagger(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.wifiSlash,
                    size: 16,
                    color: pal.moderate,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lowFrom == null
                          ? '$lowMin min with weak or no signal'
                          : '$lowMin min with weak or no signal from $lowFrom',
                      style: TextStyle(
                        color: pal.onWarningContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        // One filled action (Start), the rest tonal, in a row that bleeds
        // off the edge so you can tell there's more.
        stagger(
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(PhosphorIconsFill.navigationArrow, size: 18),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 8),
                TonalPill(
                  icon: PhosphorIconsRegular.downloadSimple,
                  label: 'Offline',
                  onTap: onOffline,
                ),
                const SizedBox(width: 8),
                TonalPill(
                  icon: PhosphorIconsRegular.clipboardText,
                  label: 'Pre-trip report',
                  onTap: onReport,
                ),
                const SizedBox(width: 8),
                TonalPill(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  label: 'Compare',
                  onTap: onCompare,
                ),
                const SizedBox(width: 8),
                TonalPill(
                  icon: PhosphorIconsRegular.shareNetwork,
                  label: 'Share',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ),
        stagger(
          SheetSectionTitle(
            'Signal along the way',
            subtitle: 'Estimated for ${operatorLabel(op)}',
          ),
        ),
        stagger(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SignalProfileChart(route: route, op: op),
          ),
        ),
        const SizedBox(height: 10),
        for (var s = 0; s < route.segments.length; s++)
          _SegmentRow(
            segment: route.segments[s],
            op: op,
            first: s == 0,
            last: s == route.segments.length - 1,
          ),
        if (others.isNotEmpty)
          const SheetSectionTitle('Other routes', subtitle: 'Tap one to switch'),
        for (final r in others)
          _OtherRouteRow(
            route: r,
            base: route,
            op: op,
            onTap: () => onSelectRoute(r.id),
          ),
        const SheetSectionTitle('Coverage by network'),
        for (final o in const ['jio', 'airtel', 'vi', 'bsnl'])
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    operatorLabel(o),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: SignalCoverageBar(
                    stats: route.stats[o] ?? route.stats['all']!,
                    height: 7,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${route.stats[o]?['good'] ?? 0}% good',
                  style: TextStyle(color: pal.muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A bar per route segment: width = distance, height and colour = expected
/// signal. Our version of a "busy hours" histogram.
class SignalProfileChart extends StatelessWidget {
  const SignalProfileChart({super.key, required this.route, required this.op});

  final JourneyRoute route;
  final String op;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final total = route.segments.fold<double>(0, (t, s) => t + s.km);
    double h(String level) => switch (level) {
      'good' => 1.0,
      'moderate' => 0.68,
      'weak' => 0.4,
      _ => 0.16,
    };
    return Semantics(
      label: 'Signal along the route chart',
      child: SizedBox(
        height: 74,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in route.segments)
              Expanded(
                flex: (s.km / total * 1000).round().clamp(1, 1000),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: h(s.levelFor(op))),
                    duration: Motion.of(context, const Duration(milliseconds: 500)),
                    curve: Motion.enter,
                    builder: (context, v, _) => FractionallySizedBox(
                      heightFactor: v.clamp(0.02, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pal.level(s.levelFor(op)).withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.segment,
    required this.op,
    required this.first,
    required this.last,
  });

  final RouteSegment segment;
  final String op;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final level = segment.levelFor(op);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 26),
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: first ? Colors.transparent : pal.border,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: pal.level(level),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
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
                children: [
                  Text(
                    segment.label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  MetaLine([
                    '${segment.km.toStringAsFixed(0)} km',
                    formatDuration(segment.min),
                  ]),
                ],
              ),
            ),
          ),
          Center(child: SignalChip(level: level, compact: true)),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _OtherRouteRow extends StatelessWidget {
  const _OtherRouteRow({
    required this.route,
    required this.base,
    required this.op,
    required this.onTap,
  });

  final JourneyRoute route;
  final JourneyRoute base;
  final String op;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final delta = route.durationMin - base.durationMin;
    final score = networkScore(route, op);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  formatDuration(route.durationMin),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(child: MetaLine([route.via])),
                Text(
                  delta == 0
                      ? 'Same time'
                      : delta > 0
                      ? '+${formatDuration(delta)}'
                      : '−${formatDuration(-delta)}',
                  style: TextStyle(
                    color: delta > 0 ? pal.moderate : pal.good,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SignalCoverageBar(
                    stats: route.stats[op] ?? route.stats['all']!,
                    height: 6,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  PhosphorIconsFill.cellSignalHigh,
                  size: 13,
                  color: scoreColor(pal, score),
                ),
                const SizedBox(width: 3),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
