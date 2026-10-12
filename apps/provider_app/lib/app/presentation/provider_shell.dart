import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'provider_tabs.dart';

/// Branch navigators retain their own widget and scroll state.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Theme(
    data: BThereTheme.authentication(),
    child: Builder(
      builder: (context) => PopScope(
        canPop: navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) navigationShell.goBranch(0);
        },
        child: Scaffold(
          body: navigationShell,
          bottomNavigationBar: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: NavigationBar(
              height: 72,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .12),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width < 360 ? 11 : 12,
                  color: states.contains(WidgetState.selected)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              destinations: [
                for (final tab in ProviderTab.values)
                  NavigationDestination(
                    icon: Icon(
                      tab.icon,
                      color: BThereColors.textSecondaryAccessible,
                    ),
                    selectedIcon: Icon(
                      tab.selectedIcon,
                      color: BThereColors.primaryAction,
                    ),
                    label: tab.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
