import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';
import 'map_widgets.dart';

/// Full-screen search. It cross-fades in over the map (see the router), with
/// the field in the same pill shape as the map's search bar so it reads as
/// the bar "opening up".
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.mode = 'destination'});

  final String mode;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        final q = _query.text.trim().toLowerCase();
        final results = session.catalog.places.where((place) {
          if (_category != null && place.category != _category) return false;
          if (q.isEmpty) return true;
          return place.name.toLowerCase().contains(q) ||
              place.subtitle.toLowerCase().contains(q) ||
              place.category.contains(q);
        }).toList();
        final settingOrigin = widget.mode == 'origin';
        final showRecents = q.isEmpty && _category == null;

        return Scaffold(
          backgroundColor: pal.surface,
          body: SafeArea(
            child: MaxWidthContent(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    // Flat state of the search bar: on a page it sits on a
                    // grey fill with a hairline instead of floating.
                    child: Container(
                      height: 54,
                      decoration: searchBarDecoration(context, flat: true),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                            icon: Icon(
                              PhosphorIconsRegular.arrowLeft,
                              color: pal.text,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _query,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(fontSize: 16, color: pal.text),
                              decoration: InputDecoration(
                                hintText: settingOrigin
                                    ? 'Choose a start point'
                                    : 'Search places',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintStyle: TextStyle(
                                  color: pal.muted,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          if (_query.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _query.clear();
                                setState(() {});
                              },
                              icon: Icon(
                                PhosphorIconsRegular.x,
                                color: pal.muted,
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                  CategoryChips(
                    selected: _category,
                    onSelected: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: results.isEmpty
                        ? _empty(context)
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              if (showRecents &&
                                  session.recents.isNotEmpty) ...[
                                _label(context, 'Recent'),
                                for (final r in session.recents)
                                  _row(
                                    context,
                                    icon: PhosphorIconsRegular
                                        .clockCounterClockwise,
                                    tint: pal.elevated,
                                    iconColor: pal.muted,
                                    title: r,
                                    onTap: () {
                                      _query.text = r;
                                      setState(() {});
                                    },
                                    trailing: Icon(
                                      PhosphorIconsRegular.arrowUpLeft,
                                      color: pal.muted,
                                      size: 18,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                _label(context, 'Places'),
                              ],
                              for (var i = 0; i < results.length; i++)
                                _placeRow(
                                      context,
                                      session,
                                      results[i],
                                      settingOrigin,
                                    )
                                    .animate(
                                      key: ValueKey(
                                        '$q-$_category-${results[i].id}',
                                      ),
                                    )
                                    .fadeIn(
                                      delay: Motion.reduced(context)
                                          ? Duration.zero
                                          : (18 * i.clamp(0, 10)).ms,
                                      duration: 200.ms,
                                    ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
    child: Text(
      text,
      style: TextStyle(
        color: context.palette.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final pal = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: iconColor),
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
                      color: pal.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _placeRow(
    BuildContext context,
    Session session,
    Place place,
    bool origin,
  ) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final km = distance(session.here, place.point) / 1000;
    return _row(
      context,
      icon: categoryIcon(place.category),
      tint: categoryTint(place.category, dark),
      iconColor: categoryAccent(place.category, pal),
      title: place.name,
      subtitle: [
        if (km > 0.05) '${km.toStringAsFixed(km < 10 ? 1 : 0)} km',
        place.subtitle,
      ].join('  ·  '),
      onTap: () {
        ref.read(sessionProvider.notifier).update((s) {
          final recent = [
            place.name,
            ...s.recents.where((r) => r != place.name),
          ].take(8).toList();
          return s.copyWith(
            originId: origin ? place.id : s.originId,
            destinationId: origin ? s.destinationId : place.id,
            recents: recent,
          );
        });
        context.pop(place.id);
      },
    );
  }

  Widget _empty(BuildContext context) {
    final pal = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 32,
              color: pal.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No places found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Try another name or clear the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _query.clear();
                setState(() => _category = null);
              },
              child: const Text('Clear search and filters'),
            ),
          ],
        ),
      ),
    );
  }
}
