import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;
import 'customer_request_payment_widget_test.dart' show ready;

Future<void> details(
  WidgetTester tester, {
  String status = 'CONFIRMED',
  int codeStatus = 200,
  int? minutesUntilStart = 20,
}) async {
  final f = await ready(tester);
  f.startCodeStatus = codeStatus;
  f.bookings = [
    {
      ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
      'status': status,
      'startDatetime': minutesUntilStart == null
          ? null
          : clock.add(Duration(minutes: minutesUntilStart)).toIso8601String(),
    },
  ];
  f.requestViewBody.addAll({'status': status, 'paymentStatus': 'RESERVED'});
  ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
      .invalidate(customerBookingHistoryProvider(12));
  await tester.tap(find.byKey(const ValueKey('customer-nav-opportunities')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Booking #70').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });
  testWidgets(
    'Booking details reveals all four digits, hides on background and fits large text',
    (tester) async {
      await details(tester);
      final clipboardWrites = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final show = find.byKey(const ValueKey('booking-start-code-action'));
      await tester.ensureVisible(show);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('booking-start-code-section')))
            .height,
        lessThanOrEqualTo(100),
      );
      expect(find.byTooltip('Hide code'), findsNothing);
      expect(clipboardWrites, isEmpty);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide code'), findsOneWidget);
      for (final digit in ['0', '4', '7', '2']) {
        expect(find.text(digit), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('booking-start-code-section')))
            .height,
        lessThanOrEqualTo(100),
      );
      final copy = find.byKey(const ValueKey('booking-start-code-copy'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(clipboardWrites, ['0472']);
      expect(find.text('Start code copied.'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide code'));
      await tester.pumpAndSettle();
      expect(find.text('Show code'), findsOneWidget);
      expect(find.byTooltip('Copy start code'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('booking-start-code-action')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide code'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byTooltip('Hide code'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-start-code-copy')),
        findsNothing,
      );
      expect(find.text('Show code'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'outside service window shows feedback and never renders digits',
    (tester) async {
      await details(tester, codeStatus: 409);
      final show = find.byKey(const ValueKey('booking-start-code-action'));
      await tester.ensureVisible(show);
      await tester.pumpAndSettle();
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.textContaining('outside its service window'), findsOneWidget);
      expect(find.byTooltip('Hide code'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('already started booking does not offer start code', (
    tester,
  ) async {
    await details(tester, status: 'IN_PROGRESS');
    expect(
      find.byKey(const ValueKey('booking-start-code-section')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final minutes in <int?>[31]) {
    testWidgets(
      'start card hidden when start is $minutes minutes away or unknown',
      (tester) async {
        await details(tester, minutesUntilStart: minutes);
        expect(
          find.byKey(const ValueKey('booking-start-code-section')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('start card appears exactly thirty minutes before start', (
    tester,
  ) async {
    await details(tester, minutesUntilStart: 30);
    expect(
      find.byKey(const ValueKey('booking-start-code-section')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final serverStatus in [200, 409]) {
    testWidgets(
      'unknown schedule trusts server window ($serverStatus) without revealing digits',
      (tester) async {
        await details(
          tester,
          minutesUntilStart: null,
          codeStatus: serverStatus,
        );
        expect(
          find.byKey(const ValueKey('booking-start-code-section')),
          serverStatus == 200 ? findsOneWidget : findsNothing,
        );
        expect(find.byTooltip('Copy start code'), findsNothing);
        expect(find.byTooltip('Hide code'), findsNothing);
        if (serverStatus == 200) expect(find.text('Show code'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
