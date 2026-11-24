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
  testWidgets('zero refund preview does not promise a wallet credit', (
    tester,
  ) async {
    final backend = CancellationBackend()
      ..preview = {
        ...cancellationJson(),
        'refundAmount': 0.0,
        'refundPercentage': 0.0,
        'retainedAmount': 10000.0,
        'cancellationFee': 0.0,
      };
    await open(tester, backend);
    await tap(
      tester,
      find.byKey(const ValueKey('booking-review-cancellation')),
    );
    expect(
      find.text('No refund under this cancellation policy'),
      findsOneWidget,
    );
    expect(find.text('LKR 0.00 to your wallet'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('cancellation-refund-toggle')));
    expect(
      find.text('No refund will be credited for this cancellation.'),
      findsOneWidget,
    );
    expect(find.text('LKR 10,000.00'), findsOneWidget);
    expect(backend.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });
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
      expect(find.text('LKR 4,800.00 to your wallet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cancellation-refund-breakdown')),
        findsNothing,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('cancellation-refund-toggle')),
      );
      expect(find.text('Retained amount'), findsOneWidget);
      expect(find.text('Cancellation fee'), findsOneWidget);
      expect(find.text('Refund amount'), findsOneWidget);
      expect(find.textContaining('24+'), findsNothing);
      expect(backend.writes, 0);
      await tap(
        tester,
        find.byKey(const ValueKey('cancellation-refund-toggle')),
      );
      expect(
        find.byKey(const ValueKey('cancellation-refund-breakdown')),
        findsNothing,
      );

      await tap(tester, find.text('Keep Booking'));
      expect(backend.writes, 0);
      await tap(tester, review);
      await tap(
        tester,
        find.byKey(const ValueKey('confirm-paid-cancellation')),
      );
      expect(backend.writes, 0);
      expect(find.text('Select a cancellation reason.'), findsOneWidget);
      final beforeOpen = tester.getRect(
        find.byKey(const ValueKey('paid-cancellation-review')),
      );
      await tap(tester, find.byKey(const ValueKey('cancellation-reason')));
      expect(
        tester.getRect(find.byKey(const ValueKey('paid-cancellation-review'))),
        beforeOpen,
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      final trigger = tester.getRect(
        find.byKey(const ValueKey('cancellation-reason')),
      );
      final menu = tester.getRect(
        find.byKey(const ValueKey('cancellation-reason-menu')),
      );
      expect(menu.left, closeTo(trigger.left, 1));
      expect(menu.right, closeTo(trigger.right, 1));
      expect(menu.top, greaterThan(trigger.bottom));
      expect(
        tester.getTopLeft(find.text('Plans changed').last).dx,
        greaterThan(menu.left + 16),
      );
      expect(
        find.text('Choose the reason that best describes your situation.'),
        findsNothing,
      );
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
    'cancellation sheet fits narrow screen with large text and keyboard',
    (tester) async {
      final backend = CancellationBackend();
      await open(tester, backend);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(const ValueKey('booking-review-cancellation')),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('cancellation-refund-toggle')),
      );
      expect(tester.takeException(), isNull);
      final note = find.widgetWithText(TextFormField, 'Add a note (optional)');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Please cancel this booking.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Keep Booking'));
      expect(backend.writes, 0);
      expect(tester.takeException(), isNull);
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
