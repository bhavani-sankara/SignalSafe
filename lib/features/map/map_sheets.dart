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
import '../../widgets/pills.dart';
import 'map_widgets.dart';
import 'route_details.dart';

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
                  // Pulled all the way up, the sheet is about your area's
                  // signal rather than the place name (Google's "Local vibe").
                  expansion > 0.6 ? 'Signal near you' : area,
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

    final op = _cardOp(session);
    final hasTrip = session.trips.isNotEmpty;
    final ready = session.trips.any(
      (t) => t.routeId == session.route.id && t.offlinePrepared,
    );

    return ListView(
      controller: scroll,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. The assistant first, like "Make plans with Ask Maps".
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: _PlanCard(
            session: session,
            onRoute: onDirections,
            onCoverage: onTripDetails,
          ),
        ),
        // 2. The one thing the app should always answer.
        const SheetSectionTitle(
          'Signal right here',
          subtitle: 'Estimated for where you are now',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NetworkTiles(session: session),
        ),
        // 3. Your trip, or a nudge to plan one.
        SheetSectionTitle(hasTrip ? 'Your trip' : 'Plan a trip'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: hasTrip
              ? _ContinueCard(
                  session: session,
                  onDirections: onDirections,
                  onDetails: onTripDetails,
                )
              : _FirstTripCard(onSearch: onDirections),
        ),
        // 4. Heads-up: dead zones on the trip, else weak areas nearby.
        SheetSectionTitle(
          hasTrip ? 'Heads-up on your route' : 'Weak-signal areas near you',
          subtitle: hasTrip
              ? 'Where ${operatorLabel(op)} drops on the way'
              : 'Within reach of ${session.origin.name.split(',').first}',
        ),
        if (hasTrip)
          for (final s in session.route.segments.where(
            (s) => s.levelFor(op) == 'none' || s.levelFor(op) == 'weak',
          ))
            _HeadsUpRow(
              title: s.label,
              subtitle:
                  '${s.km.round()} km  ·  ${formatDuration(s.min)} '
                  '${s.levelFor(op) == 'none' ? 'no signal' : 'weak signal'}',
              none: s.levelFor(op) == 'none',
              onTap: onTripDetails,
            )
        else
          for (final b in session.catalog.blackspots.take(3))
            _HeadsUpRow(
              title: b.name,
              subtitle:
                  '${(distance(here, b.points.first) / 1000).round()} km away  ·  '
                  '${b.durationMin} min with no signal',
              none: true,
              onTap: onDirections,
            ),
        // 5. Towers, and where coverage comes back.
        const SheetSectionTitle('Towers near you'),
        _Carousel(
          height: 132,
          children: [
            for (final t in towers.take(5))
              _TowerCard(
                tower: t,
                km: distance(here, t.point) / 1000,
                onTap: () => onTower(t),
              ),
          ],
        ),
        const SheetSectionTitle(
          'Where signal comes back',
          subtitle: 'Recovery points after weak stretches',
        ),
        _Carousel(
          height: 132,
          children: [
            for (final p in recoveries)
              _PlaceCard(place: p, onTap: () => onPlace(p)),
          ],
        ),
        // 6. A quick pre-drive check.
        const SheetSectionTitle('Ready to drive?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ReadyCard(
            items: [
              (
                ready,
                ready ? 'Offline route saved' : 'Save your route for offline',
              ),
              (
                session.contacts.isNotEmpty,
                session.contacts.isNotEmpty
                    ? '${session.contacts.length} SOS contacts set'
                    : 'Add an SOS contact',
              ),
              (true, 'Signal checked just now'),
            ],
          ),
        ),
        // 7. Community.
        const SheetSectionTitle('From the community'),
        for (final r in reports) _ReportRow(report: r, onTap: () => onReport(r)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SeeAllPill(label: 'See all reports', onTap: onSeeCommunity),
        ),
        const SheetSectionTitle('Help points nearby'),
        _Carousel(
          height: 132,
          children: [
            for (final p in essentials)
              _PlaceCard(place: p, onTap: () => onPlace(p)),
          ],
        ),
      ],
    );
  }
}

/// The network the explore cards talk about: the filter, or your own
/// network when the filter is "all".
String _cardOp(Session s) =>
    s.operatorFilter == 'all' ? s.preferredOperator : s.operatorFilter;

class _BandLegend extends StatelessWidget {
  const _BandLegend({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    const levels = [
      ('good', SignalBand.strong, 'strong'),
      ('moderate', SignalBand.fair, 'fair'),
      ('weak', SignalBand.weak, 'weak'),
      ('none', SignalBand.none, 'none'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (key, band, word) in levels)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: band.color(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${stats[key] ?? 0}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: pal.text,
                      ),
                    ),
                    TextSpan(text: ' $word'),
                  ],
                ),
                style: TextStyle(fontSize: 12.5, color: pal.muted),
              ),
            ],
          ),
      ],
    );
  }
}

/// Four small tiles: signal on each network where you're standing.
class _NetworkTiles extends StatelessWidget {
  const _NetworkTiles({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final here = session.route.segments.first;
    return Row(
      children: [
        for (final op in NetworkTabs.ops) ...[
          if (op != NetworkTabs.ops.first) const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final level = here.levelFor(op);
                final word = switch (level) {
                  'good' => 'Strong',
                  'moderate' => 'Fair',
                  'weak' => 'Weak',
                  _ => 'None',
                };
                final mine = op == session.preferredOperator;
                return Semantics(
                  label: '${operatorLabel(op)}: $word',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: dark
                          ? pal.elevated
                          : Color.alphaBlend(
                              pal.level(level).withValues(alpha: 0.08),
                              Colors.white,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: mine
                            ? pal.beacon.withValues(alpha: 0.6)
                            : pal.border.withValues(alpha: 0.6),
                        width: mine ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 18,
                          child: FittedBox(child: SignalBars(level: level)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          operatorLabel(op),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: pal.text,
                          ),
                        ),
                        Text(
                          word,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: pal.level(level),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown instead of "Your trip" when there's nothing planned yet.
class _FirstTripCard extends StatelessWidget {
  const _FirstTripCard({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? pal.secondaryContainer : const Color(0xFFF1F5FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We'll show where signal drops before you leave",
            style: TextStyle(fontSize: 15, color: pal.text, height: 1.35),
          ),
          const SizedBox(height: 12),
          ActionPill(
            icon: PhosphorIconsRegular.magnifyingGlass,
            label: 'Where to?',
            tone: PillTone.elevated,
            onTap: onSearch,
          ),
        ],
      ),
    );
  }
}

class _HeadsUpRow extends StatelessWidget {
  const _HeadsUpRow({
    required this.title,
    required this.subtitle,
    required this.none,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool none;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final band = none ? SignalBand.none : SignalBand.weak;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: none
                    ? (dark ? const Color(0xFF3A4150) : const Color(0xFF2B3036))
                    : band.color(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                none
                    ? PhosphorIconsBold.cellSignalSlash
                    : PhosphorIconsBold.cellSignalLow,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: pal.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: pal.muted),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight, size: 16, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.items});

  final List<(bool, String)> items;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? pal.elevated : const Color(0xFFEFF7F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final (done, label) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    done
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    size: 20,
                    color: done ? pal.good : pal.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 14.5, color: pal.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Make plans with Ask Maps", as ours: a tinted card with a title, stacked
/// suggestion pills, and a cluster of round glyphs on the right.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.session,
    required this.onRoute,
    required this.onCoverage,
  });

  final Session session;
  final VoidCallback onRoute;
  final VoidCallback onCoverage;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final from = session.origin.name.split(',').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: dark ? pal.elevated : const Color(0xFFEEF2F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Make plans with  '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          PhosphorIconsFill.sparkle,
                          size: 15,
                          color: pal.beacon,
                        ),
                      ),
                      TextSpan(
                        text: ' Signal Check',
                        style: TextStyle(
                          color: pal.beacon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: pal.text,
                  ),
                ),
                const SizedBox(height: 12),
                SuggestionPill(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  label: '$from to ${session.destination.name}?',
                  onTap: onRoute,
                ),
                const SizedBox(height: 8),
                SuggestionPill(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  label:
                      'Where does ${operatorLabel(session.preferredOperator)} drop?',
                  onTap: onCoverage,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const _GlyphCluster(),
        ],
      ),
    );
  }
}

class _GlyphCluster extends StatelessWidget {
  const _GlyphCluster();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget dot(IconData icon, Color fg, Color bg, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark
            ? Color.alphaBlend(
                fg.withValues(alpha: 0.25),
                const Color(0xFF1B232F),
              )
            : bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: dark ? const Color(0xFF1B232F) : Colors.white,
          width: 2,
        ),
      ),
      child: Icon(icon, size: size * 0.46, color: fg),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 64,
        height: 80,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: dot(
                PhosphorIconsFill.broadcast,
                const Color(0xFF1F5BD6),
                const Color(0xFFD9E5FF),
                34,
              ),
            ),
            Positioned(
              left: 0,
              top: 24,
              child: dot(
                PhosphorIconsFill.firstAid,
                const Color(0xFFD93A2F),
                const Color(0xFFFDDDDA),
                32,
              ),
            ),
            Positioned(
              right: 4,
              bottom: 0,
              child: dot(
                PhosphorIconsFill.shieldCheck,
                const Color(0xFF2E7D32),
                const Color(0xFFD6F0DA),
                30,
              ),
            ),
          ],
        ),
      ),
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
          MiniSignalBars(route: route, op: _cardOp(session)),
          const SizedBox(height: 8),
          _BandLegend(
            stats: route.stats[_cardOp(session)] ?? route.stats['all']!,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(
                    PhosphorIconsFill.arrowBendUpRight,
                    size: 18,
                  ),
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
                      : OutlinedButton.styleFrom(backgroundColor: Colors.white),
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
        itemBuilder: (context, i) =>
            SizedBox(width: width * 0.62, child: children[i]),
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
  const _TowerCard({
    required this.tower,
    required this.km,
    required this.onTap,
  });

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

/// Pinned header, measured off the Google Maps Drive sheet: a "Drive" title
/// with three round actions, then the network tabs (Jio / Airtel / Vi /
/// BSNL). At peek only the title row shows, sitting on the pill footer.
class DirectionsHeader extends StatelessWidget {
  const DirectionsHeader({
    super.key,
    required this.session,
    required this.onOperator,
    required this.onOptions,
    required this.onShare,
    required this.onClose,
  });

  final Session session;
  final ValueChanged<String> onOperator;
  final VoidCallback onOptions;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Drive',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: pal.text,
                    ),
                  ),
                ),
                CircleAction(
                  icon: PhosphorIconsRegular.slidersHorizontal,
                  tooltip: 'Route options',
                  onTap: onOptions,
                ),
                const SizedBox(width: 14),
                CircleAction(
                  icon: PhosphorIconsRegular.shareNetwork,
                  tooltip: 'Share route',
                  onTap: onShare,
                ),
                const SizedBox(width: 14),
                CircleAction(
                  icon: PhosphorIconsRegular.x,
                  tooltip: 'Close directions',
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ),
        NetworkTabs(
          route: session.route,
          selected: session.operatorFilter,
          onSelected: onOperator,
        ),
      ],
    );
  }
}

/// Start / Add stops / Share / Save, pinned to the bottom of the sheet at
/// every height (the collapsed Drive sheet is just the header and this).
class DirectionsFooter extends StatelessWidget {
  const DirectionsFooter({
    super.key,
    required this.onStart,
    required this.onAddStop,
    required this.onShare,
    required this.onSave,
    required this.onOffline,
    required this.onReport,
    required this.onCompare,
  });

  final VoidCallback onStart;
  final VoidCallback onAddStop;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onOffline;
  final VoidCallback onReport;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(
          top: BorderSide(color: pal.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: PillRow(
          children: [
            ActionPill(
              icon: PhosphorIconsRegular.navigationArrow,
              label: 'Start',
              tone: PillTone.filled,
              onTap: onStart,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.mapPinPlus,
              label: 'Add stops',
              onTap: onAddStop,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.shareNetwork,
              label: 'Share',
              onTap: onShare,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.bookmarkSimple,
              label: 'Save',
              onTap: onSave,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.downloadSimple,
              label: 'Offline',
              onTap: onOffline,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.clipboardText,
              label: 'Pre-trip report',
              onTap: onReport,
            ),
            ActionPill(
              icon: PhosphorIconsRegular.arrowsLeftRight,
              label: 'Compare',
              onTap: onCompare,
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.place,
    required this.op,
    required this.arrivalLevel,
    required this.onTap,
  });

  final Place place;
  final String op;
  final String arrivalLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final word = switch (arrivalLevel) {
      'good' => 'strong',
      'moderate' => 'fair',
      'weak' => 'weak',
      _ => 'no',
    };
    return Semantics(
      button: true,
      label: 'Destination ${place.name}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dark
                      ? pal.destination.withValues(alpha: 0.18)
                      : const Color(0xFFFDE7E6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  size: 20,
                  color: pal.destination,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pal.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (place.subtitle.isNotEmpty)
                            TextSpan(text: '${place.subtitle.split(' · ').first}  ·  '),
                          TextSpan(
                            text: '${operatorLabel(op)} $word on arrival',
                            style: TextStyle(
                              color: pal.level(arrivalLevel),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: pal.muted),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 18, color: pal.muted),
            ],
          ),
        ),
      ),
    );
  }
}

const _prefLabels = {
  'connectivity': 'Best signal',
  'balanced': 'Balanced',
  'fastest': 'Fastest',
};

class DirectionsBody extends StatelessWidget {
  const DirectionsBody({
    super.key,
    required this.session,
    required this.scroll,
    required this.physics,
    required this.loading,
    required this.onPrefs,
    required this.onDestination,
    required this.onSelectRoute,
  });

  /// Drive's resting height above the nav: handle (22) + title row and
  /// tabs (98) + chips and the ETA lines (120) + the pill footer (65).
  static const halfHeight = 305.0;

  final Session session;
  final ScrollController scroll;
  final ScrollPhysics physics;
  final bool loading;

  /// Changes a route preference; the screen re-picks the best route.
  final ValueChanged<Session Function(Session)> onPrefs;
  final VoidCallback onDestination;
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
    final none = route.segments
        .where((s) => s.levelFor(op) == 'none')
        .fold<int>(0, (t, s) => t + s.min);
    final weak = route.segments
        .where((s) => s.levelFor(op) == 'weak')
        .fold<int>(0, (t, s) => t + s.min);
    // ETA goes red when there's a dead zone, amber for weak, like traffic.
    final etaColor = none > 0
        ? pal.destination
        : weak > 0
        ? pal.moderate
        : pal.good;
    final why = none > 0
        ? '${formatDuration(none)} with no ${operatorLabel(op)} signal'
        : weak > 0
        ? '${formatDuration(weak)} of weak ${operatorLabel(op)} signal'
        : 'Signal the whole way';
    final others = session
        .rankedRoutes()
        .where((r) => r.id != route.id)
        .toList();
    final blackspot = session.catalog.blackspots.isEmpty
        ? null
        : session.catalog.blackspots.first;

    var i = 0;
    Widget stagger(Widget w) => w
        .animate(delay: (40 * i++).ms)
        .fadeIn(duration: 260.ms, curve: Motion.enter)
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Motion.enter);

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: pal.text,
        ),
      ),
    );

    final divider = Divider(height: 1, thickness: 1, color: pal.border);

    return ListView(
      key: ValueKey('content-${route.id}'),
      controller: scroll,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SizedBox(height: 14),
        // Filter chips, where Google has "Leave now ▾ · Avoid tolls · Avoid
        // highways".
        stagger(
          SizedBox(
            height: PillMetrics.chipHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                PopupMenuButton<String>(
                  // Semantics come from the chip; no hover tooltip.
                  tooltip: '',
                  position: PopupMenuPosition.under,
                  onSelected: (v) => onPrefs((s) => s.copyWith(routePref: v)),
                  itemBuilder: (_) => [
                    for (final e in _prefLabels.entries)
                      CheckedPopupMenuItem(
                        value: e.key,
                        checked: session.routePref == e.key,
                        child: Text(e.value),
                      ),
                  ],
                  child: IgnorePointer(
                    child: FilterChipPill(
                      label: _prefLabels[session.routePref] ?? 'Best signal',
                      icon: PhosphorIconsRegular.cellSignalHigh,
                      dropdown: true,
                      onTap: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChipPill(
                  label: 'Avoid blackspots',
                  selected: session.avoidLongBlackspots,
                  onTap: () => onPrefs(
                    (s) =>
                        s.copyWith(avoidLongBlackspots: !s.avoidLongBlackspots),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChipPill(
                  label: 'Near help points',
                  selected: session.stayNearServices,
                  onTap: () => onPrefs(
                    (s) => s.copyWith(stayNearServices: !s.stayNearServices),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        stagger(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatDuration(route.durationMin),
                        style: TextStyle(
                          color: etaColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: '  (${route.distanceKm.toStringAsFixed(0)} km)',
                        style: TextStyle(color: pal.text, fontSize: 17),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  route.recommended
                      ? 'Best-signal route now · $why'
                      : 'via ${route.via} · $why',
                  maxLines: 2,
                  style: TextStyle(color: pal.muted, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Destination: one clean row, no grey band.
        stagger(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DestinationRow(
              place: session.destination,
              op: op,
              arrivalLevel: route.segments.last.levelFor(op),
              onTap: onDestination,
            ),
          ),
        ),
        const SizedBox(height: 4),
        divider,
        stagger(title('Signal')),
        stagger(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SignalStretchChart(route: route, op: op),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SignalNotes(route: route, op: op, blackspot: blackspot),
        ),
        const SizedBox(height: 14),
        divider,
        title('Steps'),
        StepList(
          origin: session.origin.name,
          steps: routeSteps(route, op, session.destination.name),
        ),
        const SizedBox(height: 8),
        divider,
        if (others.isNotEmpty) ...[
          title('Other routes'),
          for (final r in others)
            _OtherRouteRow(
              route: r,
              base: route,
              op: op,
              onTap: () => onSelectRoute(r.id),
            ),
          const SizedBox(height: 8),
          divider,
        ],
        title('Coverage by network'),
        for (final o in NetworkTabs.ops)
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
