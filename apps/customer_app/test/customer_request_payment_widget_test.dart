import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/booking/application/customer_request_recovery.dart';
import 'package:customer_app/features/booking/application/customer_booking_history.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_details_screen.dart';

import 'customer_discovery_test.dart' show marketEntry, continueMarket;

import 'package:customer_app/features/booking/presentation/customer_request_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;

Future<BookingFixture> ready(
  WidgetTester tester, {
  String status = 'AWAITING_CUSTOMER_CONFIRMATION',
  String paymentStatus = 'NOT_STARTED',
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final f = BookingFixture();
  f.contextBody = contextJson(
    methods: ['WALLET', 'CARD'],
    selectionMode: 'OPEN_REQUEST',
  );
  f.requestViewBody.addAll({
    'status': status,
    'paymentStatus': paymentStatus,
    'paymentMethod': 'WALLET',
    'jobId': 70,
    'providerId': 15,
    'confirmationExpiresAt': clock
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  });
  f.requestEvents = [
    {
      'eventId': 1,
      'requestId': 501,
      'userId': 12,
      'eventType': 'PROVIDER_ACCEPTED',
    },
  ];
  f.bookings = [
    {...bookingJson(id: 70, method: 'WALLET'), 'status': 'AWAITING_PAYMENT'},
  ];
  f.install();
  addTearDown(f.f.dispose);
  await marketEntry(tester, f.f);
  await continueMarket(tester);
  return f;
}

void main() {
  testWidgets(
    'View booking details waits for fresh history without flashing retry',
    (tester) async {
      final f = await ready(tester);
      f.bookings = [];
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.invalidate(customerBookingHistoryProvider(12));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Payment required'));
      await tester.tap(find.text('Payment required'));
      await tester.pumpAndSettle();
      f.bookings = [
        {
          ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
          'status': 'CONFIRMED',
        },
      ];
      f.pendingHistory = Completer<void>();
      final pay = find.text('Confirm and Pay');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      final details = find.text('View booking details');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Retry booking details'), findsNothing);
      expect(find.text('Booking details are not available yet.'), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-details-page-skeleton')),
        findsOneWidget,
      );
      f.pendingHistory!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Booking #70'), findsOneWidget);
      expect(find.text('Funds reserved'), findsWidgets);
      expect(find.text('Retry booking details'), findsNothing);
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsNothing);
      expect(find.text('Confirm and Pay'), findsNothing);
      expect(find.text('Booking #70'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-bottom-navigation')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cancelled unpaid booking keeps accessible payment state and details summary',
    (tester) async {
      final f = await ready(tester, status: 'CANCELLED');
      f.bookings = [
        {
          ...bookingJson(id: 70, method: 'CARD', payment: 'PENDING'),
          'status': 'CANCELLED',
        },
      ];
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .invalidate(customerBookingHistoryProvider(12));
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Not paid')), findsWidgets);
      semantics.dispose();
      expect(find.text('Pending payment'), findsNothing);
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      expect(find.text('Not paid'), findsOneWidget);
      expect(find.text('Pending payment'), findsNothing);
      expect(find.text('Retry payment'), findsNothing);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/confirm'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'asynchronous card success refreshes cached booking history and details',
    (tester) async {
      final f = await ready(tester, paymentStatus: 'FAILED');
      f.requestViewBody['paymentMethod'] = 'CARD';
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerBookingDetailsScreen)),
      );
      final historySubscription = container.listen(
        customerBookingHistoryProvider(12),
        (_, _) {},
      );
      addTearDown(historySubscription.close);
      // Populate the details screen's local refresh snapshot before payment.
      final refreshed = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
          .onRefresh();
      await tester.pumpAndSettle();
      await refreshed;
      await tester.tap(find.text('Retry payment'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Failed!'), findsOneWidget);
      // A gateway callback can settle the card after the initiating tap returned.
      f.requestViewBody.addAll({
        'status': 'CONFIRMED',
        'paymentStatus': 'PAID',
      });
      f.bookings = [
        {
          ...bookingJson(id: 70, method: 'CARD', payment: 'PAID'),
          'status': 'CONFIRMED',
        },
      ];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      final historyRead = container.read(
        customerBookingHistoryProvider(12).future,
      );
      await tester.pumpAndSettle();
      final history = await historyRead;
      expect(history.single['status'], 'CONFIRMED');
      expect(history.single['paymentStatus'], 'PAID');
      // Return to the already mounted details screen, not a newly built page.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Retry payment'), findsNothing);
      expect(
        f.f.adapter.requests.where(
          (r) => r.method == 'POST' && r.path.contains('/confirm'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'payment recovery stays mounted through delayed background history refresh',
    (tester) async {
      final f = await ready(tester, paymentStatus: 'FAILED');
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(CustomerBookingDetailsScreen));
      final container = ProviderScope.containerOf(element);
      final recovery = container.read(customerRequestRecoveryProvider);
      expect(find.text('15m 0s remaining'), findsOneWidget);
      f.pendingHistory = Completer<void>();
      container.invalidate(customerBookingHistoryProvider(12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(customerBookingHistoryProvider(12)).isLoading,
        isTrue,
      );
      expect(find.text('Retry payment'), findsOneWidget);
      expect(find.text('15m 0s remaining'), findsOneWidget);
      expect(
        identical(container.read(customerRequestRecoveryProvider), recovery),
        isTrue,
      );
      f.pendingHistory!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retry payment'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failure method picker keeps request and selects saved card before explicit retry',
    (tester) async {
      final f = await ready(tester, paymentStatus: 'FAILED');
      f.mockPaymentSettings = true;
      f.hasSavedCard = true;
      await tester.ensureVisible(find.text('Payment failed'));
      await tester.tap(find.text('Payment failed'));
      await tester.pumpAndSettle();
      final change = find.byKey(const ValueKey('payment-result-change-method'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const ValueKey('retry-payment-method-WALLET')),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('retry-payment-method-CARD')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('4242').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Selected Card'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Failed!'), findsOneWidget);
      expect(find.text('Credit / Debit Card'), findsOneWidget);
      expect(find.textContaining('4242'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.method == 'POST' &&
              r.path.contains('/booking-requests/') &&
              !r.path.endsWith('/payment-method'),
        ),
        isEmpty,
      );
      final retry = find.byKey(const ValueKey('payment-result-retry'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/501/confirm-mock-card'),
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Home Recent opens accepted request; payment stays confirmed until explicit navigation',
    (tester) async {
      final f = await ready(tester);
      await tester.ensureVisible(find.text('Payment required'));
      await tester.tap(find.text('Payment required'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerRequestPaymentScreen), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      final pay = find.text('Confirm and Pay');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerRequestPaymentScreen), findsOneWidget);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        hasLength(1),
      );
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/cancel')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Booking tab and details expose same unpaid request after leaving Home',
    (tester) async {
      final f = await ready(tester);
      // Wallet insufficiency can retain NOT_STARTED: the retry timestamp is
      // authoritative even without a local failure or FAILED payment status.
      f.requestViewBody['paymentRetryStartedAt'] = clock.toIso8601String();
      f.bookings = [
        {
          ...bookingJson(id: 70, method: 'WALLET'),
          'status': 'AWAITING_PAYMENT',
        },
      ];
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment failed'), findsNothing);
      expect(find.text('Pay now'), findsNothing);
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('15m 0s remaining'), findsOneWidget);
      await tester.tap(find.text('Retry payment'));
      await tester.pumpAndSettle();
      expect(find.text('Retry payment'), findsOneWidget);
      expect(find.text('Use Different Payment Method'), findsOneWidget);
      final home = find.text('Go to Home');
      await tester.ensureVisible(home);
      await tester.tap(home);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('customer-nav-opportunities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking #70').last);
      await tester.pumpAndSettle();
      expect(find.text('Retry payment'), findsOneWidget);
      await tester.tap(find.text('Retry payment'));
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('payment-result-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('pending/reconciliation hides charge and cancellation actions', (
    tester,
  ) async {
    await ready(tester, status: 'PAYMENT_RECONCILIATION');
    await tester.ensureVisible(find.text('Checking payment'));
    await tester.tap(find.text('Checking payment'));
    await tester.pumpAndSettle();
    expect(find.text('Checking your payment'), findsOneWidget);
    expect(find.text('Confirm and Pay'), findsNothing);
    expect(find.text('Cancel request'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    '30 second warning and extension update from server without blocking actions',
    (tester) async {
      final f = await ready(tester);
      await tester.ensureVisible(find.text('Payment required'));
      await tester.tap(find.text('Payment required'));
      await tester.pumpAndSettle();
      f.requestViewBody['confirmationExpiresAt'] = clock
          .add(const Duration(seconds: 30))
          .toIso8601String();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Time is running out'), findsOneWidget);
      f.requestViewBody['confirmationExpiresAt'] = clock
          .add(const Duration(minutes: 20))
          .toIso8601String();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Time is running out'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm and Pay'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'insufficient Wallet uses failure artwork, live deadline and same-request retry at large text',
    (tester) async {
      final f = await ready(tester);
      f.walletConfirmationStatus = 409;
      await tester.ensureVisible(find.text('Payment required'));
      await tester.tap(find.text('Payment required'));
      await tester.pumpAndSettle();
      final pay = find.text('Confirm and Pay');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-payment-failed')),
        findsOneWidget,
      );
      expect(find.text('Payment Failed!'), findsOneWidget);
      expect(
        find.text('Insufficient available wallet balance'),
        findsOneWidget,
      );
      expect(find.text('Time remaining to retry'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('We found a provider!'), findsNothing);
      expect(
        find.text('Try Again will send a new provider request.'),
        findsNothing,
      );
      f.requestViewBody['confirmationExpiresAt'] = clock
          .add(const Duration(seconds: 30))
          .toIso8601String();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Time is running out'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('payment-result-retry'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      f.walletConfirmationStatus = 200;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Your booking is confirmed!'), findsOneWidget);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        hasLength(2),
      );
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.path.endsWith('/cancel') ||
              r.path.endsWith('/booking-requests'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'restored Wallet retry window opens failure UI without a local error',
    (tester) async {
      final f = await ready(tester);
      f.requestViewBody.addAll({
        'paymentStatus': 'NOT_STARTED',
        'paymentRetryStartedAt': clock.toIso8601String(),
        'confirmationExpiresAt': clock
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      });
      await tester.ensureVisible(find.text('Payment required'));
      await tester.tap(find.text('Payment required'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Failed!'), findsOneWidget);
      expect(find.text('Time remaining to retry'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('We found a provider!'), findsNothing);
      // Only payment-window guarantees retry metadata; a slower poll must not
      // replace the screen or reset its scroll between View and window reads.
      f.paymentWindowBody = {
        ...f.requestViewBody,
        'canPay': true,
        'canCancel': true,
      };
      f.requestViewBody.remove('paymentRetryStartedAt');
      final held = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/payment-window')) await held.future;
        return previous(r);
      };
      final retry = find.byKey(const ValueKey('payment-result-retry'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      final screen = tester.element(
        find.byKey(const ValueKey('booking-payment-failed')),
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('booking-payment-failed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scroll.position.pixels;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.element(find.byKey(const ValueKey('booking-payment-failed'))),
        same(screen),
      );
      expect(find.text('We found a provider!'), findsNothing);
      expect(scroll.position.pixels, offset);
      expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
      held.complete();
      await tester.pumpAndSettle();
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
