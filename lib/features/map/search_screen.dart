import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

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
        final q = _query.text.trim().toLowerCase();
        final results = session.catalog.places.where((place) {
          if (_category != null && place.category != _category) return false;
          if (q.isEmpty) return true;
          return place.name.toLowerCase().contains(q) ||
              place.subtitle.toLowerCase().contains(q) ||
              place.category.contains(q);
        }).toList();
        final settingOrigin = widget.mode == 'origin';
        return Scaffold(
          appBar: AppBar(
            title: Text(settingOrigin ? 'Choose start' : 'Search'),
          ),
          body: MaxWidthContent(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search places',
                      hintText: 'Hospital, fuel, recovery…',
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                      ),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _query.clear();
                                setState(() {});
                              },
                              icon: const Icon(PhosphorIconsRegular.x),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final item in const [
                        ('hospital', 'Hospitals'),
                        ('police', 'Police'),
                        ('fuel', 'Fuel'),
                        ('hotel', 'Hotels'),
                        ('restaurant', 'Food'),
                        ('atm', 'ATMs'),
                        ('recovery', 'Recovery'),
                        ('blackspot', 'Weak signal'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(categoryIcon(item.$1), size: 16),
                            label: Text(item.$2),
                            selected: _category == item.$1,
                            selectedColor: context.palette.beacon.withValues(
                              alpha: 0.18,
                            ),
                            checkmarkColor: context.palette.beacon,
                            side: BorderSide(
                              color: _category == item.$1
                                  ? context.palette.beacon
                                  : context.palette.border,
                            ),
                            onSelected: (_) => setState(() {
                              _category = _category == item.$1 ? null : item.$1;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                if (q.isEmpty) _recents(session),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.magnifyingGlass,
                                  size: 32,
                                  color: context.palette.muted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No places found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try another name or clear the filters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.palette.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    _query.clear();
                                    setState(() => _category = null);
                                  },
                                  child: const Text('Clear search and filters'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _tile(
                            context,
                            session,
                            results[i],
                            settingOrigin,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recents(Session session) {
    if (session.recents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Recent'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final recent in session.recents)
                ActionChip(
                  label: Text(recent),
                  onPressed: () {
                    _query.text = recent;
                    setState(() {});
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    Session session,
    Place place,
    bool origin,
  ) {
    return ListTile(
      leading: Icon(categoryIcon(place.category)),
      title: Text(place.name),
      subtitle: Text(place.subtitle),
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
        context.pop();
      },
    );
  }
}
