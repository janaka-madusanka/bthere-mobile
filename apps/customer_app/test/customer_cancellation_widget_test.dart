import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'booking_cancellation_fixture.dart';
import 'customer_request_payment_widget_test.dart' show ready;

Future<void> open(
  WidgetTester tester,
  CancellationBackend backend, {
  bool cancelled = false,
}) async {
  final f = await ready(tester);
  backend.install(f);
  f.bookings = [
    {
      ...bookingJson(
        id: 70,
        method: 'WALLET',
        payment: cancelled ? 'PARTIALLY_REFUNDED' : 'RESERVED',
      ),
      'status': cancelled ? 'CANCELLED' : 'CONFIRMED',
    },
  ];
  f.requestViewBody.addAll({
    'status': cancelled ? 'CANCELLED' : 'CONFIRMED',
    'paymentStatus': cancelled ? 'PARTIALLY_REFUNDED' : 'RESERVED',
  });
  ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
      .invalidate(customerBookingHistoryProvider(12));
  await tester.tap(find.byKey(const ValueKey('customer-nav-opportunities')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Booking #70').last);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });
  testWidgets(
    'paid cancellation previews wallet refund, Keep booking writes nothing, confirm requires reason',
    (tester) async {
      final backend = CancellationBackend();
      await open(tester, backend);
      final review = find.byKey(const ValueKey('booking-review-cancellation'));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('booking-cancellation-section')))
            .height,
        lessThanOrEqualTo(110),
      );
      await tap(tester, review);
      expect(find.text('LKR 4,800.00 back to your wallet'), findsOneWidget);
      await tap(tester, find.text('Keep booking'));
      expect(backend.writes, 0);
      await tap(tester, review);
      await tap(
        tester,
        find.byKey(const ValueKey('confirm-paid-cancellation')),
      );
      expect(backend.writes, 0);
      expect(find.text('Select a cancellation reason.'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('cancellation-reason')));
      await tap(tester, find.text('Plans changed').last);
      await tap(
        tester,
        find.byKey(const ValueKey('confirm-paid-cancellation')),
      );
      expect(backend.writes, 1);
      expect(find.text('Refunded to your wallet'), findsOneWidget);
      expect(find.text('LKR 4,800.00'), findsOneWidget);
      expect(find.text('Amount paid'), findsOneWidget);
      expect(find.text('Refund policy'), findsOneWidget);
      expect(find.text('Partially refunded'), findsWidgets);
      expect(find.text('Show code'), findsNothing);
      expect(find.text('This booking was cancelled.'), findsNothing);
      expect(
        find.byKey(const ValueKey('cancelled-booking-status')),
        findsNothing,
      );
      expect(
        find.text('Not available for a cancelled booking.'),
        findsOneWidget,
      );
      expect(review, findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'provider cancellation receipt shows only credited compensation and fits large text',
    (tester) async {
      final backend = CancellationBackend()
        ..saved = {
          ...cancellationJson(receipt: true, by: 'PROVIDER'),
          'penalty': {
            'penaltyAmount': 500.00,
            'customerShareAmount': 200.00,
            'customerPaidAmount': 50.00,
            'status': 'PARTIAL',
          },
        };
      await open(tester, backend, cancelled: true);
      expect(find.text('Compensation credited: LKR 50.00'), findsOneWidget);
      expect(find.textContaining('Additional compensation'), findsOneWidget);
      expect(find.textContaining('500.00'), findsNothing);
      expect(backend.writes, 0);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
