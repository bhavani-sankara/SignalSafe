import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/hud.dart';

// ---------------------------------------------------------------------------
// Scores and small helpers shared by the map screens
// ---------------------------------------------------------------------------

/// A 0–100 signal score for one network on a route. "All networks" uses the
/// catalogue score; single networks are derived from their coverage mix.
int networkScore(JourneyRoute route, String op) {
  if (op == 'all') return route.connectivityScore;
  final s = route.stats[op] ?? route.stats['all']!;
  return ((s['good'] ?? 0) * 1.0 +
          (s['moderate'] ?? 0) * 0.65 +
          (s['weak'] ?? 0) * 0.3)
      .round()
      .clamp(0, 100);
}

/// Minutes of weak or no signal on [route] for [op].
int lowSignalMinutes(JourneyRoute route, String op) => route.segments
    .where((s) {
      final l = s.levelFor(op);
      return l == 'none' || l == 'weak';
    })
    .fold(0, (t, s) => t + s.min);

Color scoreColor(SignalPalette pal, int score) => score >= 65
    ? pal.good
    : score >= 50
    ? pal.moderate
    : pal.weak;

Color operatorColor(String op) => switch (op) {
  'jio' => const Color(0xFF2A62D8),
  'airtel' => const Color(0xFFD22F27),
  'vi' => const Color(0xFF7A3EAE),
  'bsnl' => const Color(0xFFC08A00),
  _ => const Color(0xFF1F5BD6),
};

/// Soft background tint for a place category card (peach, lavender, …).
Color categoryTint(String category, bool dark) {
  if (dark) {
    return switch (category) {
      'hospital' => const Color(0xFF3A1F22),
      'police' => const Color(0xFF1C2A3E),
      'fuel' => const Color(0xFF3A2A16),
      'hotel' => const Color(0xFF2C2140),
      'restaurant' => const Color(0xFF35281C),
      'recovery' => const Color(0xFF15302A),
      _ => const Color(0xFF1E2430),
    };
  }
  return switch (category) {
    'hospital' => const Color(0xFFFDECEC),
    'police' => const Color(0xFFE8F0FD),
    'fuel' => const Color(0xFFFFF1E0),
    'hotel' => const Color(0xFFF1EAFB),
    'restaurant' => const Color(0xFFFCEFE6),
    'recovery' => const Color(0xFFE3F4EF),
    _ => const Color(0xFFF0F3F8),
  };
}

Color categoryAccent(String category, SignalPalette pal) => switch (category) {
  'hospital' => const Color(0xFFD93A2F),
  'police' => const Color(0xFF3567C8),
  'fuel' => const Color(0xFFD77A00),
  'hotel' => const Color(0xFF8A49C6),
  'restaurant' => const Color(0xFFB4632A),
  'atm' => const Color(0xFF476B9B),
  'recovery' => pal.good,
  'blackspot' => pal.moderate,
  _ => pal.beacon,
};

// ---------------------------------------------------------------------------
// Floating search pill (explore mode)
// ---------------------------------------------------------------------------

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.onSearch,
    required this.onProfile,
    required this.initial,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(27),
        boxShadow: softShadow(context, strength: 1.3),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: onSearch,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const _BrandMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Where to?',
                  style: TextStyle(color: pal.muted, fontSize: 16),
                ),
              ),
              Semantics(
                button: true,
                label: 'Profile',
                child: GestureDetector(
                  onTap: onProfile,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: pal.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// SignalSafe's own mark: a teal pin with signal arcs.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: pal.beacon, shape: BoxShape.circle),
      child: const Icon(
        PhosphorIconsFill.wifiHigh,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// From / to card (directions mode)
// ---------------------------------------------------------------------------

class FromToCard extends StatelessWidget {
  const FromToCard({
    super.key,
    required this.origin,
    required this.destination,
    required this.onBack,
    required this.onOrigin,
    required this.onDestination,
    required this.onSwap,
  });

  final String origin;
  final String destination;
  final VoidCallback onBack;
  final VoidCallback onOrigin;
  final VoidCallback onDestination;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(context, strength: 1.3),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(PhosphorIconsRegular.arrowLeft, color: pal.text),
          ),
          Expanded(
            child: Column(
              children: [
                _stop(
                  context,
                  icon: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.beacon, width: 3),
                    ),
                  ),
                  label: origin,
                  semantics: 'Start, $origin',
                  onTap: onOrigin,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Divider(height: 1, color: pal.border),
                ),
                _stop(
                  context,
                  icon: Icon(
                    PhosphorIconsFill.mapPin,
                    size: 16,
                    color: pal.destination,
                  ),
                  label: destination,
                  semantics: 'Destination, $destination',
                  onTap: onDestination,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Swap start and destination',
            onPressed: onSwap,
            icon: Icon(
              PhosphorIconsRegular.arrowsDownUp,
              color: pal.text,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stop(
    BuildContext context, {
    required Widget icon,
    required String label,
    required String semantics,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              SizedBox(width: 22, child: Center(child: icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chips
// ---------------------------------------------------------------------------

const mapCategories = [
  ('hospital', 'Hospitals'),
  ('police', 'Police'),
  ('fuel', 'Fuel'),
  ('recovery', 'Signal back'),
  ('hotel', 'Stays'),
  ('restaurant', 'Food'),
  ('atm', 'ATMs'),
  ('blackspot', 'Weak signal'),
];

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        clipBehavior: Clip.none,
        itemCount: mapCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label) = mapCategories[i];
          final on = selected == id;
          return Semantics(
            button: true,
            selected: on,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelected(on ? null : id),
              child: AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.enter,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: on ? pal.secondaryContainer : pal.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: on ? null : softShadow(context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      on ? PhosphorIconsBold.check : categoryIcon(id),
                      size: 15,
                      color: on
                          ? pal.onSecondaryContainer
                          : categoryAccent(id, pal),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: on ? pal.onSecondaryContainer : pal.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time + signal bubble pinned on each route line
// ---------------------------------------------------------------------------

class RouteBubble extends StatelessWidget {
  const RouteBubble({
    super.key,
    required this.duration,
    required this.score,
    required this.selected,
    required this.onTap,
    this.best = false,
  });

  final String duration;
  final int score;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final fg = selected ? Colors.white : pal.text;
    return Semantics(
      button: true,
      selected: selected,
      label: '$duration, signal score $score${best ? ', best signal' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.standard,
          curve: Motion.enter,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: selected ? pal.beacon : pal.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: softShadow(context, strength: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                duration,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                PhosphorIconsFill.cellSignalHigh,
                size: 13,
                color: selected ? Colors.white : scoreColor(pal, score),
              ),
              const SizedBox(width: 3),
              Text(
                '$score',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Network tabs: every tab shows its value, so you compare without tapping
// ---------------------------------------------------------------------------

class NetworkTabs extends StatelessWidget {
  const NetworkTabs({
    super.key,
    required this.route,
    required this.selected,
    required this.onSelected,
  });

  final JourneyRoute route;
  final String selected;
  final ValueChanged<String> onSelected;

  static const ops = ['all', 'jio', 'airtel', 'vi', 'bsnl'];

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final index = ops.indexOf(selected).clamp(0, ops.length - 1);
    return SizedBox(
      height: 54,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / ops.length;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Divider(height: 1, color: pal.border),
              ),
              AnimatedPositioned(
                duration: Motion.of(context, Motion.standard),
                curve: Motion.enter,
                left: w * index + 14,
                width: w - 28,
                bottom: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.beacon,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final op in ops)
                    Expanded(child: _tab(context, op, op == selected)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tab(BuildContext context, String op, bool on) {
    final pal = context.palette;
    final score = networkScore(route, op);
    final label = op == 'all' ? 'All' : operatorLabel(op);
    return Semantics(
      button: true,
      selected: on,
      label: '$label, signal score $score',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelected(op),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsFill.cellSignalHigh,
                  size: 13,
                  color: scoreColor(pal, score),
                ),
                const SizedBox(width: 3),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: on ? pal.text : pal.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? pal.beacon : pal.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pills
// ---------------------------------------------------------------------------

/// Light teal secondary action (no border). Pairs with one filled primary.
class TonalPill extends StatelessWidget {
  const TonalPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

/// Full-width tonal "See all ›" pill used under sheet sections.
class SeeAllPill extends StatelessWidget {
  const SeeAllPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretRight, size: 15),
          ],
        ),
      ),
    );
  }
}

/// The one coloured button on the map: a filled teal rounded square.
class PrimaryMapFab extends StatelessWidget {
  const PrimaryMapFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: softShadow(context, strength: 1.5),
        ),
        child: Material(
          color: pal.beacon,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section heading inside sheets (~20px, medium)
// ---------------------------------------------------------------------------

class SheetSectionTitle extends StatelessWidget {
  const SheetSectionTitle(this.text, {super.key, this.subtitle, this.trailing});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: pal.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: pal.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// "a · b · c" meta line with middle dots, grey 13px.
class MetaLine extends StatelessWidget {
  const MetaLine(this.parts, {super.key, this.color, this.maxLines = 1});

  final List<String> parts;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      parts.where((p) => p.isNotEmpty).join('  ·  '),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color ?? context.palette.muted, fontSize: 13),
    );
  }
}
