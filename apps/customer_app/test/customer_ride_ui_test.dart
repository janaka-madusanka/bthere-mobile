import 'package:customer_app/features/booking/data/customer_ride_route.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'booking_fixture.dart';
import 'customer_booking_widget_test.dart' show openBooking, activeJourney;

class _RideCamera extends Fake implements GoogleMapController {
  final updates = <Object?>[];
  @override
  Future<void> animateCamera(CameraUpdate update, {Duration? duration}) async {
    updates.add(update.toJson());
  }

  @override
  Future<ScreenCoordinate> getScreenCoordinate(LatLng point) async =>
      ScreenCoordinate(x: 100, y: 100);
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'route bounds refit after viewport settles and retain both endpoints',
    (tester) async {
      CustomerMapState? state;
      late StateSetter resize;
      var height = 480.0;
      var requests = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue((value) {
              state = value;
              return const SizedBox.expand();
            }),
            customerRideRouteProvider.overrideWith((ref, endpoints) async {
              requests++;
              return [
                const GeoPoint(6.9, 79.8),
                const GeoPoint(7.6, 80.1),
                const GeoPoint(7.4, 80.3),
              ];
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  resize = setState;
                  return BookingLocationPicker(
                    point: const GeoPoint(6.9, 79.8),
                    destination: const GeoPoint(7.4, 80.3),
                    onChanged: (_) {},
                    mapOnly: true,
                    height: height,
                    topPadding: 120,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final camera = _RideCamera();
      state!.onCreated(camera);
      await tester.pumpAndSettle();
      camera.updates.clear();
      resize(() => height = 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      resize(() => height = 320);
      await tester.pump();
      expect(camera.updates, isEmpty);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(camera.updates, hasLength(1));
      final update = camera.updates.single as List;
      expect(update.first, 'newLatLngBounds');
      final bounds = update[1] as List;
      expect(bounds[0], [6.9, 79.8]);
      expect(bounds[1], [7.6, 80.3]);
      expect(state!.topPadding, 120);
      expect(requests, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(camera.updates, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'route service uses trip summary and vehicle cards with dynamic booking fields',
    (tester) async {
      final f = BookingFixture();
      addTearDown(f.f.dispose);
      f.contextBody = contextJson(
        schedule: 'ROUTE_BASED',
        selectionMode: 'OPEN_REQUEST',
        methods: ['WALLET'],
        fields: [
          fieldJson(id: 21, code: 'PASSENGERS', type: 'NUMBER'),
          fieldJson(id: 22, code: 'CONTACT_PHONE', type: 'PHONE'),
        ],
      );
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 45,
          'label': 'Vehicle type',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['CAR', 'VAN'],
        },
      ];
      f.contextBody['pricingFieldIds'] = [45];
      f.policyBody = {
        'enabled': true,
        'minimumNoticeMinutes': 0,
        'maximumRadiusKm': 50,
      };
      await openBooking(tester, f);
      expect(
        tester
            .widget<DraggableScrollableSheet>(
              find.byType(DraggableScrollableSheet),
            )
            .initialChildSize,
        lessThanOrEqualTo(.36),
      );
      final c = activeJourney(tester);
      c.edit(() {
        c.point = const GeoPoint(6.9, 79.8);
        c.address = 'Colombo';
        c.destination = const GeoPoint(7.4, 80.3);
        c.destinationAddress = 'Kurunegala';
        c.start = '2030-01-07T08:00:00';
        c.languages.add('ENGLISH');
        c.skills.add(10);
        c.providerFilters[45] = ['CAR'];
      });
      await tester.pumpAndSettle();
      expect(find.text('Where are you going?'), findsOneWidget);
      expect(find.text('PASSENGERS'), findsNothing);
      expect(find.byKey(const ValueKey('booking-pickup-time')), findsNothing);
      final locations = find.byKey(const ValueKey('ride-locations-continue'));
      await tester.ensureVisible(locations);
      await tester.tap(locations);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ride-vehicle-45-CAR')), findsOneWidget);
      expect(
        tester
            .widget<DraggableScrollableSheet>(
              find.byType(DraggableScrollableSheet),
            )
            .initialChildSize,
        lessThanOrEqualTo(.48),
      );
      expect(find.byKey(const ValueKey('booking-pickup-time')), findsOneWidget);
      expect(find.text('PASSENGERS'), findsNothing);
      final next = find.byKey(const ValueKey('booking-location-continue'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(c.stage, BookingStage.serviceDetails, reason: c.error);
      expect(
        tester
            .widget<BookingLocationPicker>(find.byType(BookingLocationPicker))
            .candidates,
        isNotEmpty,
      );
      expect(find.byKey(const ValueKey('ride-route-recap')), findsOneWidget);
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(c.pricingSelections[45], 'CAR');
      expect(find.text('PASSENGERS'), findsOneWidget);
      expect(find.text('CONTACT PHONE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-details-footer')),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
      c.answers['PASSENGERS'] = 2;
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ride-vehicle-45-CAR')), findsOneWidget);
      expect(c.providerFilters[45], ['CAR']);
      expect(c.answers['PASSENGERS'], 2);
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Where are you going?'), findsOneWidget);
      expect(c.destinationAddress, 'Kurunegala');
      expect(c.availableCandidates, isNotEmpty);
      final pickupMap = tester.widget<BookingLocationPicker>(
        find.byType(BookingLocationPicker),
      );
      expect(pickupMap.candidates, isEmpty);
      expect(pickupMap.point, isNotNull);
      expect(pickupMap.destination, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'route decoder preserves all road geometry points and rejects truncation',
    () {
      final points = decodeRidePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.length, 3);
      expect(points.first.latitude, 38.5);
      expect(points.last.longitude, -126.453);
      expect(() => decodeRidePolyline('_p~iF'), throwsFormatException);
    },
  );

  testWidgets(
    'ride map shows separate destination and highlighted road geometry',
    (tester) async {
      CustomerMapState? state;
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue((value) {
              state = value;
              return const SizedBox.expand();
            }),
            customerRideRouteProvider.overrideWith((ref, endpoints) async {
              calls++;
              return [
                GeoPoint(endpoints.$1, endpoints.$2),
                const GeoPoint(7.1, 80.0),
                GeoPoint(endpoints.$3, endpoints.$4),
              ];
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingLocationPicker(
                point: const GeoPoint(6.9, 79.8),
                destination: const GeoPoint(7.4, 80.3),
                onChanged: (_) {},
                mapOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        state!.markers.any(
          (marker) => marker.markerId.value == 'ride-destination',
        ),
        isTrue,
      );
      final line = state!.polylines.singleWhere(
        (line) => line.polylineId.value == 'ride-route',
      );
      expect(line.points.length, 3);
      expect(line.width, 5);
      expect(calls, 1);
      expect(find.text('Driving route'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
