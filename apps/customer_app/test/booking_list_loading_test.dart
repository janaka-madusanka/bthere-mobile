import 'dart:async';

import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/presentation/customer_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_discovery_test.dart' show marketEntry;

void main() {
  testWidgets(
    'first read uses skeleton and refresh retains existing bookings',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.install();
      f.bookings = [bookingJson(id: 70)];
      var gate = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (request) async {
        if (request.path == '/customers/me/bookings') await gate.future;
        return previous(request);
      };
      await marketEntry(tester, f.f);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-market-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-market-continue')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bookings-loading-skeleton')),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Booking #70'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bookings-loading-skeleton')),
        findsNothing,
      );
      gate = Completer<void>();
      ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
          .invalidate(customerBookingHistoryProvider(12));
      await tester.pumpAndSettle();
      expect(find.text('Booking #70'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bookings-loading-skeleton')),
        findsNothing,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'long booking list builds viewport cards instead of every booking',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerOpportunitiesBody(
              bookings: [for (var id = 1; id <= 200; id++) bookingJson(id: id)],
              onRefresh: () async {},
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingSummaryTile).evaluate().length, lessThan(20));
      expect(find.text('Booking #200'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list skeleton fits a narrow viewport with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: CustomerBookingsSkeleton(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
