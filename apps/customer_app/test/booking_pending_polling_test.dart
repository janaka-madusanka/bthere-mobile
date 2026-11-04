import 'package:customer_app/features/booking/presentation/booking_payment_pending.dart';
import 'package:customer_app/features/booking/presentation/booking_payment_result_screen.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_booking_widget_test.dart' show openBooking, activeJourney;

void main() {
  for (final success in [true, false]) {
    testWidgets(
      'pending polls and automatically shows ${success ? 'success' : 'failure'}',
      (tester) async {
        final f = BookingFixture();
        addTearDown(f.f.dispose);
        await openBooking(tester, f);
        final c = activeJourney(tester);
        c.created = {
          ...f.requestViewBody,
          'status': 'PAYMENT_PENDING',
          'paymentStatus': 'PENDING',
        };
        c.stage = BookingStage.created;
        f.requestViewBody['status'] = 'PAYMENT_PENDING';
        f.requestViewBody['paymentStatus'] = 'PENDING';
        final initialRead = c.refreshCreatedRequest();
        await tester.pumpAndSettle();
        await initialRead;
        expect(find.byType(BookingPaymentPending), findsOneWidget);
        f.requestViewBody['status'] = success ? 'CONFIRMED' : 'PAYMENT_PENDING';
        f.requestViewBody['paymentStatus'] = success ? 'RESERVED' : 'FAILED';
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.byType(BookingPaymentPending), findsNothing);
        expect(
          tester
              .widget<BookingPaymentResultScreen>(
                find.byType(BookingPaymentResultScreen),
              )
              .success,
          success,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'pending pauses in background, skips busy reads and cancels on disposal',
    (tester) async {
      var reads = 0;
      Future<void> show({bool busy = false, bool auto = true}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingPaymentPending(
                  requestId: 501,
                  amount: null,
                  method: 'WALLET',
                  busy: busy,
                  onRefresh: () => reads++,
                  autoRefresh: auto,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show();
      await tester.pump(const Duration(seconds: 5));
      expect(reads, 1);
      await show(busy: true);
      await tester.pump(const Duration(seconds: 5));
      expect(reads, 1);
      await show();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(reads, 2);
      await show(auto: false);
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 2);
    },
  );
}
