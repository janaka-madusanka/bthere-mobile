import 'dart:async';

import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/booking/presentation/customer_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;
import 'booking_fixture.dart';

void main() {
  testWidgets(
    'home placeholders wait for catalog and support small screens with large text',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await marketEntry(tester, f);
      final gate = Completer<void>();
      f.adapter.pendingServices[1] = gate;
      await continueMarket(tester);
      expect(
        find.byKey(const ValueKey('customer-home-loading-skeleton')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('customer-find-help')), findsNothing);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-home-loading-skeleton')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('customer-find-help')), findsNothing);
      expect(find.text('Explore Services'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'recent services use skeleton during first history read and retain rows on refresh',
    (tester) async {
      final f = BookingFixture();
      await tester.runAsync(f.start);
      addTearDown(f.dispose);
      var gate = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerAuthControllerProvider.overrideWithValue(f.f.controller),
            customerBookingHistoryProvider(12)
                .overrideWith((ref) => gate.future),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CustomerRecentBookings()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-recent-loading-skeleton')),
        findsOneWidget,
      );
      gate.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No recent bookings yet.'), findsOneWidget);
      gate = Completer<List<Map<String, dynamic>>>();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerRecentBookings)),
      );
      container.invalidate(customerBookingHistoryProvider(12));
      await tester.pumpAndSettle();
      expect(find.text('No recent bookings yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-recent-loading-skeleton')),
        findsNothing,
      );
      gate.complete([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
