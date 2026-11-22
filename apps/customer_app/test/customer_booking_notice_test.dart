import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;

void main() {
  test(
    'option notice wins over policy; default rounds up to five minutes',
    () async {
      final f = BookingFixture();
      f.contextBody['selection']['option'].addAll({
        'minimumNoticeMinutes': 121,
        'instantBooking': false,
      });
      await f.start();
      addTearDown(f.dispose);
      expect(f.journey.minimumNoticeMinutes, 121);
      expect(f.journey.start, '2030-01-01T07:35:00');
      f.journey.start = '2030-01-01T06:00:00';
      expect(f.journey.startTimeError, contains('121'));
    },
  );
  test('Book now serializes current market time and preserves duration as clock advances', () async {
    final f = BookingFixture();
    f.contextBody['selection']['option'].addAll({
      'minimumNoticeMinutes': 0,
      'instantBooking': true,
    });
    await f.start();
    addTearDown(f.dispose);
    var current = clock;
    final c = CustomerBookingController(
      const BookingKey(1, 3, 12),
      f.journey.repository,
      f.f.controller,
      f.discovery,
      now: () => current,
      autoAvailability: false,
    );
    await c.load();
    addTearDown(c.dispose);
    c.point = const GeoPoint(6.9, 79.8);
    c.address = 'Colombo';
    expect(c.bookNow, isTrue);
    expect(c.startTimeError, isNull);
    final first = c.searchInput(locationStep: true);
    current = current.add(const Duration(minutes: 7));
    final next = c.searchInput(locationStep: true);
    expect(
      DateTime.parse(next['startAt'] as String)
          .difference(DateTime.parse(first['startAt'] as String)),
      const Duration(minutes: 7),
    );
    expect(
      DateTime.parse(next['endAt'] as String)
          .difference(DateTime.parse(next['startAt'] as String)),
      const Duration(hours: 6),
    );
    c.chooseBookNow(false);
    expect(c.bookNow, isFalse);
    expect(c.startTimeError, isNull);
  });
  test('instant quote remains reviewable while final POST uses fresh time and preserved duration', () async {
    final f = BookingFixture();
    f.contextBody['selection']['option'].addAll({
      'minimumNoticeMinutes': 0,
      'instantBooking': true,
    });
    await f.start();
    addTearDown(f.dispose);
    var current = clock;
    final c = CustomerBookingController(
      const BookingKey(1, 3, 12),
      f.journey.repository,
      f.f.controller,
      f.discovery,
      now: () => current,
      autoAvailability: false,
    );
    await c.load();
    addTearDown(c.dispose);
    c.point = const GeoPoint(6.9, 79.8);
    c.address = 'Colombo';
    await c.search();
    c.select(c.candidates.first);
    await c.previewQuote();
    expect(c.quote, isNotNull);
    current = current.add(const Duration(minutes: 7));
    expect(c.quote, isNotNull);
    await c.submit();
    final sent =
        f.f.adapter.requests
                .singleWhere(
                  (r) =>
                      r.method == 'POST' && r.path == '/customers/me/bookings',
                )
                .data
            as Map;
    expect(sent['startDatetime'], '2030-01-01T05:37:00');
    expect(sent['expectedEndDatetime'], '2030-01-01T11:37:00');
  });
  test(
    'instant ride estimate uses pickup time and no time-based interval fields',
    () async {
      final f = BookingFixture();
      f.contextBody = contextJson(
        schedule: 'ROUTE_BASED',
        selectionMode: 'OPEN_REQUEST',
      );
      f.contextBody['selection']['option'].addAll({
        'minimumNoticeMinutes': 0,
        'instantBooking': true,
      });
      await f.start();
      addTearDown(f.dispose);
      final c = f.journey;
      c.point = const GeoPoint(6.9, 79.8);
      c.destination = const GeoPoint(7.4, 80.3);
      c.address = 'Colombo';
      c.destinationAddress = 'Kurunegala';
      final body = c.openEstimateInput()['booking'] as Map;
      expect(body['requestedPickupTime'], '2030-01-01T05:30:00');
      expect(body.containsKey('startDatetime'), isFalse);
      expect(body.containsKey('expectedEndDatetime'), isFalse);
    },
  );
  testWidgets(
    'instant schedule chooser offers Book now and switches to scheduled picker',
    (tester) async {
      final f = BookingFixture();
      f.contextBody['selection']['option'].addAll({
        'minimumNoticeMinutes': 0,
        'instantBooking': true,
      });
      await tester.runAsync(f.start);
      addTearDown(f.dispose);
      Widget view() => ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: f.journey,
                builder: (_, _) => BookingSchedulePicker(controller: f.journey),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-book-now')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('booking-schedule-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-start-time')), findsOneWidget);
      expect(f.journey.startTimeError, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
