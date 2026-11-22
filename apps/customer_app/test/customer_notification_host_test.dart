import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/data/customer_push_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_booking_notifications_test.dart' show FakeCustomerPush, push;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'home notification settings and verified push open the actual owned booking',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture(), gateway = FakeCustomerPush();
      addTearDown(f.f.dispose);
      addTearDown(gateway.dispose);
      f.bookings = [
        {
          ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
          'status': 'CONFIRMED',
        },
      ];
      f.requestViewBody.addAll({
        'status': 'CONFIRMED',
        'jobId': 70,
        'paymentStatus': 'RESERVED',
      });
      f.install();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path == '/me/booking-devices') {
          return ResponseBody.fromString(
            jsonEncode({'deviceId': 77}),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return previous(r);
      };
      f.f.wrapApp = (child) => ProviderScope(
        overrides: [customerPushGatewayProvider.overrideWithValue(gateway)],
        child: child,
      );
      await marketEntry(tester, f.f);
      await continueMarket(tester);
      await tester.tap(
        find.byKey(const ValueKey('customer-home-notifications')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Booking notifications'), findsOneWidget);
      await tester.tap(find.text('Check notification settings'));
      await tester.pumpAndSettle();
      expect(gateway.prompts, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      gateway.messageStream.add(push(event: 99));
      await tester.pumpAndSettle();
      expect(find.text('Your booking has an update.'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Booking details'), findsOneWidget);
      expect(find.text('Booking #70'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
