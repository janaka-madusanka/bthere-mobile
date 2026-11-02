import 'package:customer_app/features/discovery/presentation/customer_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'main navigation opens Services and Home and preserves bookings access',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await marketEntry(tester, f);
      await continueMarket(tester);
      expect(
        tester
            .widget<CustomerBottomNavigation>(
              find.byType(CustomerBottomNavigation),
            )
            .selected,
        CustomerNavigationTab.home,
      );
      await tester.tap(find.byKey(const ValueKey('customer-nav-messages')));
      await tester.pumpAndSettle();
      expect(find.text('Messages coming soon.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('customer-nav-services')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomerBottomNavigation>(
              find.byType(CustomerBottomNavigation),
            )
            .selected,
        CustomerNavigationTab.services,
      );
      await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-home-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My bookings'));
      await tester.pumpAndSettle();
      expect(find.text('My bookings'), findsOneWidget);
    },
  );

  testWidgets(
    'navigation fits small displays and supports enlarged text and system inset',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                padding: const EdgeInsets.only(bottom: 34),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                bottomNavigationBar: CustomerBottomNavigation(
                  selected: CustomerNavigationTab.home,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-nav-wallet')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
