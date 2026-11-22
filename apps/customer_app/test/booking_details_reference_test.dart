import 'package:customer_app/app/customer_providers.dart';
import 'package:customer_app/features/booking/presentation/booking_details_reference.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_details_screen.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_map.dart';
import 'package:customer_app/features/booking/data/customer_ride_route.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/domain/booking_tracking.dart';
import 'package:customer_app/features/booking/presentation/customer_live_tracking_map.dart';
import 'package:customer_app/features/booking/presentation/customer_map_marker_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'booking_fixture.dart';
import 'customer_live_tracking_test.dart' show liveTrackingJson, timestamp;

void main() {
  testWidgets(
    'header keeps identity and state readable at narrow widths and enlarged text',
    (tester) async {
      for (final width in [320.0, 560.0]) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                customerClockProvider.overrideWithValue(
                  () => DateTime.utc(2026, 11, 19),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: MediaQuery(
                          data: MediaQueryData(
                            textScaler: TextScaler.linear(scale),
                          ),
                          child: BookingDetailsIdentity(
                            name: 'Hospital and home caregiver support',
                            jobId: 7001,
                            status: 'CONFIRMED',
                            start: DateTime.utc(2026, 11, 19, 4, 23),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Booking #7001'), findsOneWidget);
          expect(find.text('Ready'), findsOneWidget);
          expect(find.text('Starts in 4 hr 23 min'), findsOneWidget);
          expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
          expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
          final header = tester.getRect(
            find.byKey(const ValueKey('booking-details-header')),
          );
          final chip = tester.getRect(
            find.byKey(const ValueKey('booking-id-chip')),
          );
          final state = tester.getRect(
            find.byKey(const ValueKey('booking-status-pill')),
          );
          expect(chip.right, lessThanOrEqualTo(header.right + .1));
          expect(state.right, lessThanOrEqualTo(header.right + .1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
    },
  );
  test('booking map accepts documented flat coordinates and rejects incomplete or invalid pairs', () {
    final point = bookingLocationPoint({
      'latitude': 6.9271,
      'longitude': 79.8612,
    });
    expect(point?.latitude, 6.9271);
    expect(point?.longitude, 79.8612);
    expect(bookingLocationPoint({'latitude': 6.9}), isNull);
    expect(bookingLocationPoint({'latitude': 200, 'longitude': 79}), isNull);
    expect(bookingLocationPoint({'latitude': null, 'longitude': null}), isNull);
    expect(bookingLocationPoint({'latitude': 0, 'longitude': 0})?.latitude, 0);
  });
  testWidgets(
    'compact live map uses real road geometry and drops route when provider is stale',
    (tester) async {
      var calls = 0, lines = 0;
      final container = ProviderContainer(
        overrides: [
          customerClockProvider.overrideWithValue(
            () => timestamp.add(const Duration(seconds: 5)),
          ),
          customerMarkerIconLoaderProvider.overrideWithValue((_) async => null),
          customerRideRouteProvider.overrideWith((ref, endpoints) async {
            calls++;
            return [
              GeoPoint(endpoints.$1, endpoints.$2),
              GeoPoint(endpoints.$3, endpoints.$4),
            ];
          }),
          customerMapBuilderProvider.overrideWithValue((state) {
            lines = state.polylines.length;
            return const SizedBox(height: 174);
          }),
        ],
      );
      addTearDown(container.dispose);
      Future<void> pump(bool stale) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: CustomerLiveTrackingMap(
                compact: true,
                tracking: BookingTrackingStatus.parse(
                  liveTrackingJson(stale: stale),
                  70,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(false);
      expect(lines, 1);
      expect(calls, 1);
      await pump(true);
      expect(lines, 0);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test(
    'countdown converts market wall time and never guesses a missing timezone',
    () {
      tz.initializeTimeZones();
      final booking = {'startDatetime': '2026-11-19T10:00:00'};
      expect(
        bookingScheduledInstant(booking, 'Asia/Colombo'),
        DateTime.utc(2026, 11, 19, 4, 30),
      );
      expect(bookingScheduledInstant(booking, null), isNull);
      expect(
        bookingScheduledInstant({
          'startDatetime': '2026-11-19T10:00:00Z',
        }, null),
        DateTime.utc(2026, 11, 19, 10),
      );
    },
  );
  testWidgets(
    'reference has real map pin, countdown, collapsible answers and responsive money',
    (tester) async {
      final now = DateTime.utc(2026, 11, 19);
      var markers = 0;
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerClockProvider.overrideWithValue(() => now),
              customerMapBuilderProvider.overrideWithValue((state) {
                markers = state.markers.length;
                return const ColoredBox(
                  color: Colors.teal,
                  child: Center(child: Text('Service pin map')),
                );
              }),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SizedBox(
                      width: 320,
                      child: CustomerBookingDetailsView(
                        booking: {
                          ...bookingJson(method: 'WALLET', payment: 'RESERVED'),
                          'status': 'CONFIRMED',
                          'meetingPointName': 'Hospital Road, Colombo',
                          'meetingPoint': {
                            'latitude': 6.93,
                            'longitude': 79.86,
                          },
                          'answers': {'CG_PATIENT_NAME': 'Janaka'},
                        },
                        scheduledStart: now.add(
                          const Duration(hours: 4, minutes: 23),
                        ),
                        serviceName: 'Caregiver',
                        onBookings: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(markers, 1);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Starts in 4 hr 23 min'), findsOneWidget);
        expect(find.text('Partially paid'), findsNothing);
        expect(find.text('Janaka'), findsNothing);
        await tester.ensureVisible(find.text('Patient details'));
        await tester.tap(find.text('Patient details'));
        await tester.pumpAndSettle();
        expect(find.text('Janaka'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
