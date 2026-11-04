import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_request_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [
    'CANCELLED',
    'EXPIRED',
    'UNMATCHED',
    'CONFIRMED',
    'AWAITING_CUSTOMER_CONFIRMATION',
  ]) {
    testWidgets(
      '$status receipt shows current actions and forwards the selected action',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? action;
        await tester.pumpWidget(
          MaterialApp(
            theme: CustomerTheme.authentication(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingRequestReceipt(
                  request: {
                    'requestId': 501,
                    'jobId': status == 'CONFIRMED' ? 701 : null,
                    'status': status,
                    'paymentStatus': status == 'CONFIRMED'
                        ? 'RESERVED'
                        : 'NOT_STARTED',
                    'paymentMethod': 'WALLET',
                    'expectedAmount': 42000,
                    'currencyCode': 'LKR',
                  },
                  onRefresh: () => action = 'refresh',
                  onConfirmWallet: () => action = 'pay',
                  onHome: () => action = 'home',
                  onBookingForm: () => action = 'form',
                  onBookingDetails: () => action = 'details',
                  onSendAgain: () => action = 'resend',
                  onBookingFilters: () => action = 'filters',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.radio_button_checked), findsNothing);
        expect(find.text('Refresh request status'), findsNothing);
        expect(find.text('Back to Home'), findsOneWidget);
        final key = switch (status) {
          'CANCELLED' => 'booking-cancelled-edit',
          'EXPIRED' => 'booking-expired-send-again',
          'UNMATCHED' => 'booking-unmatched-send-again',
          'CONFIRMED' => 'booking-confirmed-details',
          _ => 'booking-confirm-wallet',
        };
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        expect(action, switch (status) {
          'CANCELLED' => 'form',
          'EXPIRED' => 'resend',
          'UNMATCHED' => 'resend',
          'CONFIRMED' => 'details',
          _ => 'pay',
        });
        if (status == 'EXPIRED') {
          final form = find.byKey(const ValueKey('booking-expired-edit'));
          await tester.ensureVisible(form);
          await tester.pumpAndSettle();
          await tester.tap(form);
          expect(action, 'form');
        }
        if (status == 'UNMATCHED') {
          expect(find.text('No provider accepted'), findsOneWidget);
          final filters = find.byKey(
            const ValueKey('booking-unmatched-filters'),
          );
          await tester.ensureVisible(filters);
          await tester.pumpAndSettle();
          await tester.tap(filters);
          expect(action, 'filters');
        }
      },
    );
  }
}
