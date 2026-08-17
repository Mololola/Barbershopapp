import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent bottom-nav chrome wrapping each StatefulShellRoute branch.
/// One instance of this is used for the customer shell and a separate one
/// for the business shell (see router.dart) — same widget, different
/// destinations passed in, since the two roles need different tab sets.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell, required this.destinations});

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-active tab pops it back to its root instead
          // of leaving you stranded on whatever nested screen you'd pushed.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: destinations,
      ),
    );
  }
}
