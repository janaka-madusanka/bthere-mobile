import 'package:customer_app/features/discovery/presentation/customer_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final raised = tester.getRect(
        find.byKey(const ValueKey('customer-selected-tab-indicator')),
      );
      final footer = tester.getRect(
        find.byKey(const ValueKey('customer-bottom-navigation')),
      );
      final wallet = tester.getRect(
        find.byKey(const ValueKey('customer-nav-icon-wallet')),
      );
      expect(raised.top, lessThan(wallet.top));
      expect(find.text('Home'), findsOneWidget);
      expect(footer.contains(raised.topCenter), isTrue);
      expect(
        raised.center.dx,
        closeTo(
          tester.getCenter(find.byKey(const ValueKey('customer-nav-home'))).dx,
          .1,
        ),
      );
      expect(find.text('Booking'), findsOneWidget);
      expect(find.text('Opportunities'), findsNothing);
      expect(
        tester
            .widget<CustomerBottomNavigation>(
              find.byType(CustomerBottomNavigation),
            )
            .selected,
        CustomerNavigationTab.home,
      );
      expect(find.byKey(const ValueKey('customer-nav-messages')), findsNothing);
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
      expect(
        tester
            .getCenter(
              find.byKey(const ValueKey('customer-selected-tab-indicator')),
            )
            .dx,
        closeTo(
          tester
              .getCenter(find.byKey(const ValueKey('customer-nav-services')))
              .dx,
          .1,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bookings'), findsNothing);
      expect(find.text('All'), findsWidgets);
      expect(find.text('No bookings yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-nav-profile')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-home-account')));
      await tester.pumpAndSettle();
      expect(find.text('My bookings'), findsNothing);
      expect(find.text('Sign out all sessions'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bookings'), findsNothing);
      expect(find.text('All'), findsWidgets);
    },
  );

  testWidgets('selected pill moves between tabs and respects reduced motion', (
    tester,
  ) async {
    Widget app(CustomerNavigationTab selected, {bool reduced = false}) =>
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                bottomNavigationBar: CustomerBottomNavigation(
                  selected: selected,
                ),
              ),
            ),
          ),
        );
    double center() => tester
        .getCenter(
          find.byKey(const ValueKey('customer-selected-tab-indicator')),
        )
        .dx;
    await tester.pumpWidget(app(CustomerNavigationTab.home));
    final start = center();
    await tester.pumpWidget(app(CustomerNavigationTab.wallet));
    await tester.pump(const Duration(milliseconds: 100));
    final middle = center();
    await tester.pumpAndSettle();
    final end = center();
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
    await tester.pumpWidget(app(CustomerNavigationTab.services, reduced: true));
    await tester.pump();
    expect(
      center(),
      closeTo(
        tester
            .getCenter(find.byKey(const ValueKey('customer-nav-services')))
            .dx,
        .1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation fits small displays and supports enlarged text and system inset',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
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
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final footer = tester.getRect(
          find.byKey(const ValueKey('customer-bottom-navigation')),
        );
        expect(footer.bottom, closeTo(568, .1));
        final control = tester.getRect(
          find.byKey(const ValueKey('customer-nav-home')),
        );
        expect(control.bottom, lessThanOrEqualTo(footer.bottom - 34));
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-nav-wallet')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
