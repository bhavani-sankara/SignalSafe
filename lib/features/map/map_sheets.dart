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

    return ListView(
      controller: scroll,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: _PlanCard(
            session: session,
            onRoute: onDirections,
            onCoverage: onTripDetails,
          ),
        ),
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
              _TowerCard(
                tower: t,
                km: distance(here, t.point) / 1000,
                onTap: () => onTower(t),
              ),
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
            for (final p in essentials)
              _PlaceCard(place: p, onTap: () => onPlace(p)),
          ],
        ),
        const SheetSectionTitle('From the community'),
        for (final r in reports)
          _ReportRow(report: r, onTap: () => onReport(r)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SeeAllPill(label: 'See all reports', onTap: onSeeCommunity),
        ),
      ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
        // Destination card on a grey band.
        stagger(
          Container(
            color: dark ? pal.ink : const Color(0xFFF1F3F6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Material(
              color: pal.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onDestination,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        PhosphorIconsRegular.mapPin,
                        size: 22,
                        color: pal.text,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          session.destination.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, color: pal.text),
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 18,
                        color: pal.text,
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
