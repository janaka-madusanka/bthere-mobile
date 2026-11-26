import 'package:bthere_network/bthere_network.dart';

import 'support/booking_ui/booking_ui_lab.dart';
import 'support/booking_ui/booking_ui_lab_backend.dart';
import 'support/booking_ui/booking_ui_lab_map.dart';

import 'package:customer_app/features/booking/presentation/customer_booking_details_screen.dart';
import 'package:customer_app/features/messages/presentation/customer_messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);
  test('lab transport rejects real hosts and unknown actions cannot fall through to network', () async {
    final backend = BookingLabBackend(BookingLabScene.ready);
    addTearDown(backend.close);
    await expectLater(
      backend.fetch(
        RequestOptions(
          path: '/customers/me/bookings',
          baseUrl: 'https://example.com/api/v1',
        ),
        null,
        null,
      ),
      throwsStateError,
    );
    final response = await backend.fetch(
      RequestOptions(
        path: '/unknown-action',
        method: 'POST',
        baseUrl: BookingLabRuntime.api,
      ),
      null,
      null,
    );
    expect(response.statusCode, 501);
    expect(backend.booking['status'], 'CONFIRMED');
  });

  testWidgets(
    'Ready reuses production widgets; sample call/chat and start code stay in the lab',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const BookingUiLab());
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingDetailsScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-bottom-navigation')),
        findsNothing,
      );
      expect(find.text('Ready'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^Starts in 04:2[23]:[0-5][0-9]$')),
        findsOneWidget,
      );
      expect(find.byType(BookingLabMap), findsOneWidget);
      expect(find.text('Nimal Perera'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Nimal Perera')).dy,
        greaterThan(tester.getBottomLeft(find.byType(BookingLabMap)).dy),
      );
      expect(find.text('Hospital Care'), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-service-image')), findsNothing);
      expect(find.text('Show code'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Call provider'));
      await tester.tap(find.byTooltip('Call provider'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sample call only. No phone app was opened.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Message provider'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerChatScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-lab-scenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-lab-scene-ready-code')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(RegExp(r'^Starts in 00:2[23]:[0-5][0-9]$')),
        findsOneWidget,
      );
      final show = find.byKey(const ValueKey('booking-start-code-action'));
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide code'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-start-code-copy')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'scenario reset discards simulated actions and font/width controls preserve the real screen',
    (tester) async {
      await tester.pumpWidget(
        const BookingUiLab(initialScene: BookingLabScene.readyCode),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-lab-scale')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-lab-scale')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-lab-width')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('ui-lab-reset')));
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(find.byTooltip('Hide code'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final scene in BookingLabScene.values.where(
    (s) => s != BookingLabScene.loading,
  )) {
    testWidgets('${scene.id} scenario uses isolated sample state', (
      tester,
    ) async {
      await tester.pumpWidget(BookingUiLab(initialScene: scene));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'loading scenario holds the real full-page skeleton until reset',
    (tester) async {
      await tester.pumpWidget(
        const BookingUiLab(initialScene: BookingLabScene.loading),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('booking-details-page-skeleton')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
