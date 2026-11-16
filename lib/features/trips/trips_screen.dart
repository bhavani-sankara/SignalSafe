import 'package:flutter/cupertino.dart'
    show CupertinoButton, CupertinoSliverNavigationBar;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/frosted.dart';
import '../../widgets/hud.dart';
import '../../widgets/route_mini_map.dart';
import '../../widgets/session_gate.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        final journeys = session.trips
            .where((trip) => trip.kind == 'saved' || trip.offlinePrepared)
            .toList();
        var stagger = 0;
        Widget enter(Widget child) => child
            .animate(delay: (40 * stagger++).ms)
            .fadeIn(duration: Motion.standard, curve: Motion.settle)
            .slideY(
              begin: 0.06,
              end: 0,
              duration: Motion.emphasized,
              curve: Motion.enter,
            );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Trips'),
                transitionBetweenRoutes: false,
                automaticallyImplyLeading: false,
                backgroundColor: pal.ink.withValues(alpha: 0.86),
                border: Border(
                  bottom: BorderSide(
                    color: pal.border.withValues(alpha: 0.6),
                    width: 0,
                  ),
                ),
                trailing: Tooltip(
                  message: 'Add a place',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => context.push('/search?mode=destination'),
                    child: Icon(
                      PhosphorIconsBold.plus,
                      color: pal.beacon,
                      size: 22,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: MaxWidthContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      enter(_searchPill(context)),
                      const SizedBox(height: 16),
                      enter(
                        SizedBox(
                          height: 64,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              for (final place in session.catalog.savedPlaces)
                                _placePill(context, ref, place),
                              _newPlacePill(context),
                            ],
                          ),
                        ),
                      ),
                      enter(
                        _header(
                          context,
                          'Saved journeys',
                          trailing: journeys.isEmpty
                              ? null
                              : '${journeys.length} saved',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (journeys.isEmpty)
                SliverToBoxAdapter(
                  child: MaxWidthContent(child: enter(_empty(context))),
                )
              else
                SliverList.builder(
                  itemCount: journeys.length,
                  itemBuilder: (context, i) => MaxWidthContent(
                    child: enter(_JourneyCard(trip: journeys[i])),
                  ),
                ),
              SliverToBoxAdapter(
                child: MaxWidthContent(
                  child: enter(
                    _header(
                      context,
                      'Recent searches',
                      action: session.recents.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () => ref
                                  .read(sessionProvider.notifier)
                                  .update((s) => s.copyWith(recents: const [])),
                              child: const Text('Clear'),
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: MaxWidthContent(
                  child: enter(_recents(context, session)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _searchPill(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PressScale(
        onTap: () => context.push('/search?mode=destination'),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: floatShadow(context, lift: 0.5),
          ),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.magnifyingGlass, color: pal.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Where to next?',
                  style: TextStyle(color: pal.muted, fontSize: 16),
                ),
              ),
              Icon(PhosphorIconsRegular.path, color: pal.beacon, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String text, {
    String? trailing,
    Widget? action,
  }) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: pal.text,
                fontSize: 20,
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailing,
                style: TextStyle(color: pal.muted, fontSize: 13),
              ),
            ),
          ?action,
        ],
      ),
    );
  }

  Widget _placePill(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> place,
  ) {
    final label = place['label']!.split(' · ');
    final isHome = label.first.toLowerCase() == 'home';
    final pal = context.palette;
    final tint = isHome ? pal.beacon : pal.destination;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: PressScale(
        onTap: () {
          ref
              .read(sessionProvider.notifier)
              .update((s) => s.copyWith(destinationId: place['id']));
          context.go('/map');
        },
        child: Semantics(
          button: true,
          label: 'Go to ${label.join(', ')}',
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: pal.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHome
                        ? PhosphorIconsFill.houseLine
                        : PhosphorIconsFill.mapPinLine,
                    color: tint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.first,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: pal.text,
                      ),
                    ),
                    if (label.length > 1)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          label.skip(1).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: pal.muted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newPlacePill(BuildContext context) {
    final pal = context.palette;
    return PressScale(
      onTap: () => context.push('/search?mode=destination'),
      child: Semantics(
        button: true,
        label: 'New place',
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pal.elevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(PhosphorIconsRegular.plus, color: pal.muted),
              ),
              const SizedBox(width: 10),
              Text(
                'New place',
                style: TextStyle(color: pal.text, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final pal = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: pal.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(PhosphorIconsRegular.path, color: pal.beacon),
          ),
          const SizedBox(height: 14),
          Text(
            'Your next journey starts with a route.',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Compare routes and save one to keep it here.',
            style: TextStyle(color: pal.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/map'),
            icon: const Icon(PhosphorIconsRegular.mapTrifold),
            label: const Text('Find a route'),
          ),
        ],
      ),
    );
  }

  Widget _recents(BuildContext context, Session session) {
    final pal = context.palette;
    if (session.recents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Text(
          'Places you search for will appear here.',
          style: TextStyle(color: pal.muted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: pal.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < session.recents.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 72,
                  color: pal.border.withValues(alpha: 0.5),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pal.elevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: pal.text,
                    size: 20,
                  ),
                ),
                title: Text(
                  session.recents[i],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Icon(
                  PhosphorIconsRegular.arrowUpLeft,
                  color: pal.muted,
                  size: 18,
                ),
                onTap: () => context.go('/map'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A saved journey: live mini-map hero, route summary, coverage, actions.
class _JourneyCard extends ConsumerWidget {
  const _JourneyCard({required this.trip});

  final SavedTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider)!;
    final route = session.catalog.routeById(trip.routeId);
    final origin = session.catalog.place(trip.originId);
    final destination = session.catalog.place(trip.destinationId);
    final op = session.operatorFilter;
    final stats = route.stats[op] ?? route.stats['all']!;
    final lowMin = route.segments
        .where((s) {
          final l = s.levelFor(op);
          return l == 'weak' || l == 'none';
        })
        .fold<int>(0, (t, s) => t + s.min);
    final pal = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: PressScale(
        scale: 0.985,
        onTap: () => context.push('/trip/${trip.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: floatShadow(context, lift: 0.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'trip-map-${trip.id}',
                    child: RouteMiniMap(
                      route: route,
                      context: session.catalog.routes,
                      operator: op,
                      height: 156,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Badge(
                      icon: PhosphorIconsFill.clock,
                      text: formatDuration(route.durationMin),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _Badge(
                      icon: PhosphorIconsFill.cellSignalHigh,
                      text: '${route.connectivityScore}',
                      color: route.connectivityScore >= 70
                          ? pal.good
                          : pal.weak,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                    const SizedBox(height: 10),
                    _Stops(
                      from: origin.name.split(',').first,
                      to: destination.name,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Stat(
                          icon: PhosphorIconsRegular.ruler,
                          text: '${route.distanceKm.toStringAsFixed(0)} km',
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: lowMin == 0
                              ? PhosphorIconsRegular.wifiHigh
                              : PhosphorIconsRegular.wifiSlash,
                          text: lowMin == 0
                              ? 'Connected throughout'
                              : '${formatDuration(lowMin)} low signal',
                          color: lowMin == 0 ? pal.good : pal.weak,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CoverageStrip(stats: stats, height: 6),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (trip.offlinePrepared)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Tooltip(
                                message: 'This saved plan does not include downloaded map tiles.',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.successContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIconsBold.check,
                                        size: 14,
                                        color: pal.onSuccessContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Offline plan · demo',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: pal.onSuccessContainer,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/trip/${trip.id}'),
                          child: const Text('Details'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: () => _start(context, ref),
                          icon: const Icon(
                            PhosphorIconsFill.navigationArrow,
                            size: 16,
                          ),
                          label: const Text('Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref) {
    ref
        .read(sessionProvider.notifier)
        .update(
          (s) => s.copyWith(
            selectedRouteId: trip.routeId,
            originId: trip.originId,
            destinationId: trip.destinationId,
            navProgress: 0.05,
          ),
        );
    context.push('/navigate');
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Frosted(
      borderRadius: BorderRadius.circular(14),
      lift: 0.4,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? pal.beacon),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: pal.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stops extends StatelessWidget {
  const _Stops({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    Widget line(IconData icon, Color color, String text) => Row(
      children: [
        SizedBox(width: 18, child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: pal.text, fontSize: 14),
          ),
        ),
      ],
    );
    return Column(
      children: [
        line(PhosphorIconsFill.circle, pal.beacon, from),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 10, color: pal.border),
          ),
        ),
        line(PhosphorIconsFill.mapPin, pal.destination, to),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? pal.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? pal.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
