import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/domain/booking_tracking.dart';
import 'package:customer_app/features/booking/presentation/customer_live_tracking_map.dart';
import 'package:customer_app/features/booking/presentation/tracking_provider_details.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_map.dart';
import 'package:customer_app/features/booking/presentation/customer_map_marker_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_tracking_status_test.dart' show trackingJson;

final timestamp = DateTime.utc(2026, 11, 10, 8);
Map<String, dynamic> liveTrackingJson({
  bool stale = false,
  bool location = true,
}) => {
  ...trackingJson(status: 'EN_ROUTE'),
  'staleAfterSeconds': 30,
  'target': {'label': 'SERVICE_LOCATION', 'latitude': 6.92, 'longitude': 79.85},
  'providerDisplayFields': [
    {
      'fieldId': 4,
      'label': 'Vehicle type',
      'options': [
        {'value': 'CAR', 'label': 'Car'},
      ],
    },
  ],
  'providers': [
    {
      'providerId': 18,
      'displayName': 'Kasun Perera',
      'profilePhoto': null,
      'averageRating': null,
      'totalRatings': 0,
      'providerAttributes': {'4': 'CAR'},
      'status': 'EN_ROUTE',
      'mapMarker': {
        'icon': {'url': 'https://example.invalid/car.png'},
      },
      'location': location
          ? {
              'latitude': 6.9,
              'longitude': 79.8,
              'headingDegrees': 120,
              'recordedAt': timestamp.toIso8601String(),
            }
          : null,
      'stale': stale,
      'distanceKm': 1.6,
      'etaMinutes': 4,
    },
  ],
};
void main() {
  test('tracking parses real provider markers and location age without assuming GPS', () {
    final data = BookingTrackingStatus.parse(liveTrackingJson(), 70),
        p = BookingTrackingStatus.parse(
          liveTrackingJson(),
          70,
        ).providers.single;
    expect(p.heading, 120);
    expect(p.marker, contains('car.png'));
    expect(data.target!.latitude, 6.92);
    expect(p.stale(timestamp.add(const Duration(seconds: 29)), 30), isFalse);
    expect(p.stale(timestamp.add(const Duration(seconds: 30)), 30), isTrue);
    expect(
      BookingTrackingStatus.parse(
        liveTrackingJson(location: false),
        70,
      ).providers.single.point,
      isNull,
    );
    expect(
      () => BookingTrackingStatus.parse({
        ...liveTrackingJson(),
        'target': {'latitude': 999, 'longitude': 0},
      }, 70),
      throwsFormatException,
    );
  });
  testWidgets(
    'live map distinguishes provider and destination, rotates marker and has no fake route',
    (tester) async {
      CustomerMapState? state;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue((s) {
              state = s;
              return const SizedBox.expand();
            }),
            customerMarkerIconLoaderProvider.overrideWithValue(
              (_) async => null,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerLiveTrackingMap(
                tracking: BookingTrackingStatus.parse(liveTrackingJson(), 70),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(state!.markers.length, 2);
      final provider = state!.markers.singleWhere(
        (m) => m.markerId.value == 'tracking-provider-18',
      );
      expect(provider.rotation, 120);
      expect(provider.position.latitude, 6.9);
      expect(
        state!.markers.any((m) => m.markerId.value == 'tracking-target'),
        isTrue,
      );
      expect(state!.polylines, isEmpty);
      expect(state!.onSelect, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'provider card uses approved field metadata and hides stale ETA without hiding provider',
    (tester) async {
      Future<void> pump({bool stale = false, bool location = true}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: CustomerTheme.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TrackingProviderDetails(
                    tracking: BookingTrackingStatus.parse(
                      liveTrackingJson(stale: stale, location: location),
                      70,
                    ),
                    now: timestamp,
                  ),
                ),
              ),
            ),
          );
      await pump();
      expect(find.text('Approx. 4 min to you'), findsOneWidget);
      expect(find.text('Vehicle type: Car'), findsOneWidget);
      await pump(stale: true);
      expect(find.text('Updating location…'), findsOneWidget);
      expect(find.textContaining('Approx.'), findsNothing);
      expect(find.text('Kasun Perera'), findsOneWidget);
      await pump(location: false);
      expect(find.text('Waiting for shared location…'), findsOneWidget);
      expect(find.textContaining('Approx.'), findsNothing);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
