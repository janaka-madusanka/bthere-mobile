import 'package:customer_app/features/booking/presentation/booking_payment_result_screen.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_details_screen.dart';
import 'package:customer_app/features/booking/presentation/customer_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact booking cards fit narrow screens at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 850),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: BookingSummaryTile(
                    booking: {
                      ...bookingJson(id: 37),
                      'status': 'COMPLETED',
                      'expectedAmount': 2100000,
                    },
                    name: 'Hospital and home caregiver support',
                    onTap: () => opened = true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Rs. 2,100,000.00'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('customer-booking-37')));
        expect(opened, isTrue);
      },
    );
  }
  testWidgets('verified success opens details once after three seconds', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPaymentResultScreen(
          success: true,
          subtitle: 'Confirmed',
          onHome: () {},
          onBooking: () {},
          onAutoContinue: () => opened++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(opened, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(opened, 1);
  });

  testWidgets(
    'manual home cancels success auto navigation and failure never redirects',
    (tester) async {
      var opened = 0;
      var home = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPaymentResultScreen(
            success: true,
            subtitle: 'Confirmed',
            onHome: () => home++,
            onBooking: () {},
            onAutoContinue: () => opened++,
          ),
        ),
      );
      final homeButton = find.text('Go to Home');
      await tester.ensureVisible(homeButton);
      await tester.tap(homeButton);
      await tester.pump(const Duration(seconds: 4));
      expect(home, 1);
      expect(opened, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPaymentResultScreen(
            success: false,
            subtitle: 'Declined',
            onHome: () {},
            onBooking: () {},
            onAutoContinue: () => opened++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(opened, 0);
    },
  );

  testWidgets(
    'opportunities filters actual bookings and opens selected booking',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerOpportunitiesBody(
              bookings: [
                bookingJson(id: 1),
                {...bookingJson(id: 2), 'status': 'COMPLETED'},
                {...bookingJson(id: 3), 'status': 'CANCELLED'},
              ],
              onRefresh: () async {},
              onOpen: (row) => selected = row['jobId'] as int,
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-booking-1')), findsNothing);
      expect(find.byKey(const ValueKey('customer-booking-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('customer-booking-2')));
      expect(selected, 2);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-booking-3')), findsOneWidget);
    },
  );

  testWidgets(
    'booking details render answers and real amount without inventing provider profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CustomerBookingDetailsView(
                booking: {
                  ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
                  'status': 'CONFIRMED',
                  'answers': {
                    'PERSON_NAME': 'Janaka',
                    'WARD_NUMBER': '10A',
                    'CG_BED_NUMBER': '12',
                    'CG_ADDITIONAL_INFORMATION':
                        'Mobility assistance requested.',
                  },
                },
                onBookings: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Booking #70'), findsOneWidget);
      expect(find.text('Janaka'), findsNothing);
      await tester.ensureVisible(find.text('Patient details'));
      await tester.tap(find.text('Patient details'));
      await tester.pumpAndSettle();
      expect(find.text('Janaka'), findsOneWidget);
      expect(find.text('10A'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Mobility assistance requested.'), findsOneWidget);
      expect(find.text('Patient details'), findsOneWidget);
      expect(find.text('Partially paid'), findsNothing);
      expect(find.text('Assigned provider'), findsOneWidget);
      expect(
        find.text('Profile details are not available yet.'),
        findsOneWidget,
      );
      expect(find.text('Rs. 2,400.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
