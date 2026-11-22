import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;
import 'customer_request_payment_widget_test.dart' show ready;

Future<BookingFixture> openProgress(WidgetTester tester) async {
  final f = await ready(tester);
  f.bookings = [
    {
      ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
      'status': 'CONFIRMED',
      'startDatetime': clock.add(const Duration(minutes: 20)).toIso8601String(),
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
  return f;
}

void main() {
  testWidgets(
    'details progress updates header, hides START code and reaches completed without writes',
    (tester) async {
      final f = await openProgress(tester);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('View service timeline'), findsNothing);
      final show = find.byKey(const ValueKey('booking-start-code-action'));
      await tester.ensureVisible(show);
      await tester.pumpAndSettle();
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide code'), findsOneWidget);
      const states = {
        'IN_PROGRESS': 'In progress',
        'AWAITING_COMPLETION_CONFIRMATION': 'Awaiting your confirmation',
        'COMPLETED': 'Completed',
      };
      for (final entry in states.entries) {
        f.bookings = [
          {
            ...f.bookings.single,
            'status': entry.key,
            if (entry.key == 'COMPLETED') 'paymentStatus': 'SETTLED',
          },
        ];
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('View service timeline'), findsNothing);
        expect(
          find.byKey(const ValueKey('booking-start-code-section')),
          findsNothing,
        );
        expect(find.text('Show code'), findsNothing);
      }
      expect(
        f.f.adapter.requests
            .where((r) => r.path.contains('/bookings/'))
            .every((r) => r.method == 'GET'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('background and covered routes do not poll progress', (
    tester,
  ) async {
    final f = await openProgress(tester);
    final before = f.f.adapter.requests
        .where((r) => r.path == '/customers/me/bookings')
        .length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(
      f.f.adapter.requests
          .where((r) => r.path == '/customers/me/bookings')
          .length,
      before,
    );
    f.bookings = [
      {...f.bookings.single, 'status': 'IN_PROGRESS'},
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('In progress'), findsOneWidget);
    final dialog = showDialog<void>(
      context: tester.element(
        find.byKey(const ValueKey('booking-service-progress')),
      ),
      builder: (_) => const AlertDialog(content: Text('Covered details')),
    );
    await tester.pumpAndSettle();
    final covered = f.f.adapter.requests
        .where((r) => r.path == '/customers/me/bookings')
        .length;
    await tester.pump(const Duration(seconds: 10));
    expect(
      f.f.adapter.requests
          .where((r) => r.path == '/customers/me/bookings')
          .length,
      covered,
    );
    Navigator.of(tester.element(find.text('Covered details'))).pop();
    await dialog;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
