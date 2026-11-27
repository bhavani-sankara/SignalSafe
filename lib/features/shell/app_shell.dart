import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (
      label: 'Map',
      icon: PhosphorIconsRegular.mapTrifold,
      selectedIcon: PhosphorIconsFill.mapTrifold,
    ),
    (
      label: 'Trips',
      icon: PhosphorIconsRegular.path,
      selectedIcon: PhosphorIconsFill.path,
    ),
    (
      label: 'Safety',
      icon: PhosphorIconsRegular.shieldChevron,
      selectedIcon: PhosphorIconsFill.shieldChevron,
    ),
    (
      label: 'Community',
      icon: PhosphorIconsRegular.usersThree,
      selectedIcon: PhosphorIconsFill.usersThree,
    ),
    (
      label: 'Profile',
      icon: PhosphorIconsRegular.userCircle,
      selectedIcon: PhosphorIconsFill.userCircle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        final pal = context.palette;

        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: pal.elevated,
                  minWidth: 80,
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(i),
                  selectedIconTheme:
                      IconThemeData(color: pal.beacon, size: 22),
                  unselectedIconTheme:
                      IconThemeData(color: pal.muted, size: 22),
                  selectedLabelTextStyle: TextStyle(
                    color: pal.beacon,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: pal.muted,
                    fontSize: 11,
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ],
            ),
          );
        }

        // Floating pill nav for phone widths
        return Scaffold(
          body: shell,
          extendBody: true,
          bottomNavigationBar: _FloatingNav(
            currentIndex: shell.currentIndex,
            onTap: (i) => shell.goBranch(i),
            destinations: _destinations,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Floating pill navigation bar with a sliding tonal indicator
// ---------------------------------------------------------------------------

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({String label, IconData icon, IconData selectedIcon})>
  destinations;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final duration = Motion.of(context, const Duration(milliseconds: 280));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        (bottomPad + 8).clamp(12.0, 44.0),
      ),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: dark ? pal.elevated : pal.surface,
          borderRadius: BorderRadius.circular(33),
          border: dark ? Border.all(color: pal.border) : null,
          boxShadow: softShadow(context, strength: 1.4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            const pillWidth = 56.0;
            return Stack(
              children: [
                // The tonal pill slides to the active tab.
                AnimatedPositioned(
                  duration: duration,
                  curve: Motion.enter,
                  left: itemWidth * currentIndex + (itemWidth - pillWidth) / 2,
                  top: 9,
                  width: pillWidth,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pal.secondaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          label: destinations[i].label,
                          icon: destinations[i].icon,
                          selectedIcon: destinations[i].selectedIcon,
                          selected: currentIndex == i,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? pal.onSecondaryContainer : const Color(0xFF143E9C);

    return Semantics(
      selected: selected,
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  switchInCurve: Motion.enter,
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: 21,
                    color: selected ? active : pal.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.quick,
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.labelSmall?.fontFamily,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? pal.text : pal.muted,
              ),
              child: Text(label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
