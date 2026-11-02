import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'provider_navigation_bar.dart';
import '../../features/bookings/presentation/booking_offer_host.dart';

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
          if (!didPop) navigationShell.goBranch(0, initialLocation: true);
        },
        child: Scaffold(
          body: BookingOfferHost(child: navigationShell),
          bottomNavigationBar: ProviderNavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onSelect: (index) =>
                navigationShell.goBranch(index, initialLocation: true),
          ),
        ),
      ),
    ),
  );
}
