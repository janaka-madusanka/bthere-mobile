import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_tracking_status_test.dart' show TrackingBackend, trackingJson;
import 'customer_request_payment_widget_test.dart' show ready;

Future<void> openTracking(WidgetTester tester, TrackingBackend backend) async {
  final f = await ready(tester);
  backend.install(f);
  f.bookings = [
    {
      ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
      'status': 'CONFIRMED',
    },
  ];
  f.requestViewBody.addAll({
    'status': 'CONFIRMED',
    'paymentStatus': 'RESERVED',
  });
  ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
      .invalidate(customerBookingHistoryProvider(12));
  await tester.tap(find.byKey(const ValueKey('customer-nav-opportunities')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Booking #70').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'booking journey updates at backend interval, pauses background and ends without writes',
    (tester) async {
      final backend = TrackingBackend();
      await openTracking(tester, backend);
      expect(find.text('Scheduled'), findsOneWidget);
      final initial = backend.calls;
      backend.body = trackingJson(status: 'EN_ROUTE');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(backend.calls, initial);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Provider on the way'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = backend.calls;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(backend.calls, paused);
      backend.body = trackingJson(status: 'ARRIVED');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Provider has arrived'), findsOneWidget);
      backend.body = trackingJson(status: 'ENDED');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Tracking ended'), findsOneWidget);
      final ended = backend.calls;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(backend.calls, ended);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('unsupported tracking hides itself and stops polling', (
    tester,
  ) async {
    final backend = TrackingBackend()
      ..body = trackingJson(status: 'NOT_SUPPORTED');
    await openTracking(tester, backend);
    expect(find.byKey(const ValueKey('booking-tracking-status')), findsNothing);
    final calls = backend.calls;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(backend.calls, calls);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'missing tracking has explicit retry and status card fits large text',
    (tester) async {
      final backend = TrackingBackend()..status = 404;
      await openTracking(tester, backend);
      expect(find.text('Check tracking status'), findsOneWidget);
      backend.status = 200;
      final retry = find.text('Check tracking status');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
