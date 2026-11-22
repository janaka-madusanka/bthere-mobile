import 'package:customer_app/features/booking/domain/booking_tracking.dart';
import 'package:customer_app/features/booking/presentation/booking_navigation_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_tracking_status_test.dart' show trackingJson;

void main() {
  test('navigation only permits HTTPS Google Maps directions to the authorized target', () {
    BookingTrackingStatus value(String link) => BookingTrackingStatus.parse({
      ...trackingJson(status: 'EN_ROUTE'),
      'target': {'latitude': 6.9, 'longitude': 79.8, 'navigationUrl': link},
    }, 70);
    expect(
      value(
        'https://www.google.com/maps/dir/?api=1&destination=6.9,79.8&travelmode=driving',
      ).navigation,
      isNotNull,
    );
    for (final link in [
      'javascript:alert(1)',
      'https://www.google.com.evil.test/maps/dir/?api=1&destination=6.9,79.8',
      'http://www.google.com/maps/dir/?api=1&destination=6.9,79.8',
      'https://www.google.com/maps/dir/?api=1&destination=0,0',
    ]) {
      expect(value(link).navigation, isNull);
    }
  });
  testWidgets(
    'directions opens only on explicit tap and handles missing external app',
    (tester) async {
      var calls = 0;
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=6.9,79.8',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerNavigationLauncherProvider.overrideWithValue((value) async {
              expect(value, uri);
              calls++;
              return false;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(body: BookingNavigationLink(uri: uri)),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.byKey(const ValueKey('booking-open-navigation')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('could not be opened'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
