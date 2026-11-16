import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // Content scrolls beneath the translucent bar.
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: (dark ? Colors.white : Colors.black).withValues(
                    alpha: 0.06,
                  ),
                ),
              ),
            ),
            child: NavigationBar(
              height: 76,
              elevation: 0,
              backgroundColor: pal.surface.withValues(alpha: dark ? 0.8 : 0.84),
              surfaceTintColor: Colors.transparent,
              indicatorColor: pal.primaryContainer,
              animationDuration: const Duration(milliseconds: 420),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.mapTrifold),
                  selectedIcon: Icon(PhosphorIconsFill.mapTrifold),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.path),
                  selectedIcon: Icon(PhosphorIconsFill.path),
                  label: 'Trips',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.shieldChevron),
                  selectedIcon: Icon(PhosphorIconsFill.shieldChevron),
                  label: 'Safety',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.usersThree),
                  selectedIcon: Icon(PhosphorIconsFill.usersThree),
                  label: 'Community',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.userCircle),
                  selectedIcon: Icon(PhosphorIconsFill.userCircle),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
