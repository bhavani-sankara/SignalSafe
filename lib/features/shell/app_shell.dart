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
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        height: 78,
        backgroundColor: pal.elevated,
        indicatorColor: pal.beacon.withValues(alpha: 0.16),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index),
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
    );
  }
}
