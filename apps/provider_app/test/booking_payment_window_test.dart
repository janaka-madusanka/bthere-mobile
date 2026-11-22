import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/bookings/application/booking_controller.dart';
import 'package:provider_app/features/bookings/data/booking_repository.dart';
import 'package:provider_app/features/bookings/domain/booking_models.dart';
import 'package:provider_app/features/bookings/presentation/booking_payment_window.dart';

final now = DateTime.utc(2030, 1, 2, 12);

class WindowRepository extends BookingRepository {
  WindowRepository(this.status, this.expired)
    : super(
        ApiClient(
          config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        ),
      );
  final String status;
  final bool expired;
  @override
  Future<BookingPaymentWindow> paymentWindow(int requestId) async =>
      BookingPaymentWindow.fromJson({
        'requestId': requestId,
        'status': status,
        'paymentStatus': status == 'PAYMENT_PENDING' ? 'PENDING' : 'FAILED',
        'confirmationExpiresAt': now
            .add(Duration(minutes: expired ? -1 : 10))
            .toIso8601String(),
        'paymentDeadlineLimit': now
            .add(const Duration(minutes: 25))
            .toIso8601String(),
        'canCancel': status != 'PAYMENT_PENDING',
        'canExtend': status != 'PAYMENT_PENDING',
      });
}

class WindowController extends BookingController {
  DateTime? target;
  int? cancelled;
  @override
  Future<BookingState> build() async => const BookingState();
  @override
  Future<bool> extendDeadline(int requestId, DateTime value) async {
    target = value;
    return true;
  }

  @override
  Future<bool> cancelUnpaid(int requestId) async {
    cancelled = requestId;
    return true;
  }
}

void main() {
  for (final mode in ['unpaid', 'pending', 'expired']) {
    testWidgets('$mode window gates provider controls', (tester) async {
      final repository = WindowRepository(
        mode == 'pending'
            ? 'PAYMENT_PENDING'
            : 'AWAITING_CUSTOMER_CONFIRMATION',
        mode == 'expired',
      );
      final controller = WindowController();
      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(repository),
          bookingControllerProvider.overrideWith(() => controller),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() => repository.client.close(force: true));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingPaymentWindowCard(
                  requestId: 501,
                  serviceStart: '2030-01-02T12:30:00Z',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == 'unpaid') {
        expect(find.text('Cancel unpaid booking'), findsOneWidget);
        await tester.tap(find.text('Extend deadline'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SimpleDialogOption).first);
        await tester.pumpAndSettle();
        expect(controller.target, now.add(const Duration(minutes: 15)));
        expect(controller.target!.isUtc, isTrue);
        await tester.tap(find.text('Cancel unpaid booking'));
        await tester.pumpAndSettle();
        expect(controller.cancelled, isNull);
        await tester.tap(find.text('Cancel booking'));
        await tester.pumpAndSettle();
        expect(controller.cancelled, 501);
      } else {
        expect(find.text('Extend deadline'), findsNothing);
        expect(find.text('Cancel unpaid booking'), findsNothing);
        expect(
          find.textContaining(
            mode == 'pending' ? 'being verified' : 'has ended',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
