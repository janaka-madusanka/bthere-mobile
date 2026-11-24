import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'booking_cancellation_fixture.dart';
import 'customer_auth_test.dart' show clock;
import 'customer_request_payment_widget_test.dart' show ready;

void main() {
  testWidgets(
    'deadline never cancels locally; polling applies server cancellation and refund',
    (tester) async {
      final f = await ready(
        tester,
        status: 'CONFIRMED',
        paymentStatus: 'RESERVED',
      );
      final backend = CancellationBackend()..install(f);
      final waiting = {
        ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
        'status': 'CONFIRMED',
        'startDatetimeUtc': clock
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
        'autoCancelAt': clock
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
        'autoCancelHold': null,
      };
      f.bookings = [waiting];
      ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
          .invalidate(customerBookingHistoryProvider(12));
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      expect(find.text('Cancelling...'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-auto-cancelled')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Cancelling...'), findsOneWidget);
      final receipt = {
        ...cancellationJson(receipt: true, by: 'SYSTEM'),
        'refundAmount': 10000,
        'cancellationFee': 0,
        'paymentStatus': 'REFUNDED',
        'reason': 'PROVIDER_DID_NOT_START',
        'automatic': true,
      };
      backend.saved = receipt;
      f.bookings = [
        {
          ...waiting,
          'status': 'CANCELLED',
          'paymentStatus': 'REFUNDED',
          'autoCancelAt': null,
          'cancellation': receipt,
        },
      ];
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-auto-cancelled')),
        findsOneWidget,
      );
      expect(find.text('Book again'), findsOneWidget);
      expect(
        find.textContaining('10000'),
        findsNothing,
      ); // formatted currency, not raw JSON
      expect(find.byKey(const ValueKey('booking-auto-cancel')), findsNothing);
      expect(backend.writes, 0);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.endsWith('/cancel'),
        ),
        isEmpty,
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
