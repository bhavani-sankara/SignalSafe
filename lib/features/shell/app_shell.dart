import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../theme/app_theme.dart';

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
// Floating frosted-glass pill navigation bar
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, (bottomPad + 12).clamp(16.0, 48.0)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: dark
                  ? pal.elevated.withValues(alpha: 0.92)
                  : pal.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: dark
                    ? pal.border.withValues(alpha: 0.6)
                    : pal.border.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
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
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(
          begin: 0.3,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
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

    return Semantics(
      selected: selected,
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? pal.beacon : pal.muted,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? pal.beacon : pal.muted,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: selected ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: pal.beacon,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
