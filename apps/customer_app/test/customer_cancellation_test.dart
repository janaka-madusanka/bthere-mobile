import 'dart:async';

import 'package:customer_app/features/booking/application/customer_cancellation_controller.dart';
import 'package:customer_app/features/booking/domain/booking_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'booking_cancellation_fixture.dart';

void main() {
  late BookingFixture f;
  late CancellationBackend backend;
  late CustomerCancellationController c;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    f.bookings = [
      {
        ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
        'status': 'CONFIRMED',
      },
    ];
    backend = CancellationBackend()..install(f);
    c = CustomerCancellationController(f.journey.repository, f.f.controller, {
      ...f.bookings.single,
    });
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test('preview is read only; confirm sends exact shown refund and blocks duplicate settlement', () async {
    expect(await c.prepare(), isTrue);
    expect(backend.writes, 0);
    backend.gate = Completer<void>();
    backend.started = Completer<void>();
    final action = c.confirm('Plans changed', '');
    await backend.started!.future;
    await c.confirm('Plans changed', '');
    expect(backend.writes, 1);
    backend.gate!.complete();
    await action;
    expect(c.receipt!.refund, 4800);
    expect(c.booking['status'], 'CANCELLED');
    final sent =
        f.f.adapter.requests
                .singleWhere((r) => r.path.endsWith('/bookings/70/cancel'))
                .data
            as Map;
    expect(sent['expectedRefundAmount'], 4800);
    expect(sent['reason'], 'Plans changed');
    expect(sent['note'], isNull);
    await c.confirm('again', '');
    expect(backend.writes, 1);
  });
  test(
    'refund conflict requires a new preview and explicit confirmation',
    () async {
      await c.prepare();
      backend.postStatus = 409;
      await c.confirm('Plans changed', '');
      expect(c.preview, isNull);
      expect(c.receipt, isNull);
      expect(c.uncertain, isFalse);
      expect(backend.writes, 1);
      backend.preview['refundAmount'] = 4000.00;
      backend.postStatus = 200;
      await c.prepare();
      expect(c.preview!.refund, 4000);
      expect(backend.writes, 1);
      await c.confirm('Plans changed', '');
      expect(c.receipt!.refund, 4000);
    },
  );
  test('service started after cached details prevents cancellation preview or write', () async {
    f.bookings = [
      {...f.bookings.single, 'status': 'IN_PROGRESS'},
    ];
    expect(await c.prepare(), isFalse);
    expect(c.eligible, isFalse);
    expect(backend.writes, 0);
    expect(
      f.f.adapter.requests.where(
        (r) => r.path.endsWith('/cancellation-preview'),
      ),
      isEmpty,
    );
  });
  test('provider cancellation racing an open details page recovers receipt without a write', () async {
    f.bookings = [
      {
        ...f.bookings.single,
        'status': 'CANCELLED',
        'paymentStatus': 'REFUNDED',
      },
    ];
    backend.saved = cancellationJson(receipt: true, by: 'PROVIDER');
    expect(await c.prepare(), isFalse);
    expect(c.receipt, isNotNull);
    expect(backend.writes, 0);
  });
  test('unknown write reconciles saved cancellation with GET, never automatic POST', () async {
    await c.prepare();
    backend.timeout = true;
    backend.saved = cancellationJson(receipt: true);
    await c.confirm('Plans changed', '');
    expect(backend.writes, 1);
    expect(c.receipt, isNotNull);
    expect(c.uncertain, isFalse);
  });
  test(
    'failed reconciliation blocks cancellation until an owned read resolves it',
    () async {
      await c.prepare();
      backend.timeout = true;
      backend.receiptStatus = 503;
      await c.confirm('Plans changed', '');
      expect(c.uncertain, isTrue);
      expect(await c.prepare(), isFalse);
      expect(backend.writes, 1);
      backend.receiptStatus = 404;
      await c.loadReceipt();
      expect(c.uncertain, isFalse);
      expect(backend.writes, 1);
    },
  );
  test('late cancellation result after logout is discarded', () async {
    await c.prepare();
    backend.gate = Completer<void>();
    backend.started = Completer<void>();
    final action = c.confirm('Plans changed', '');
    await backend.started!.future;
    await f.f.controller.logout();
    backend.gate!.complete();
    await action;
    expect(c.alive, isFalse);
    expect(c.receipt, isNull);
    expect(c.booking, isEmpty);
  });
  test('provider compensation shows credited amount, not total penalty or owed share', () async {
    backend.saved = {
      ...cancellationJson(receipt: true, by: 'PROVIDER'),
      'penalty': {
        'penaltyAmount': 500.00,
        'customerShareAmount': 200.00,
        'customerPaidAmount': 50.00,
        'status': 'PARTIAL',
      },
      'providerSuspended': false,
    };
    await c.loadReceipt();
    expect(c.receipt!.data['penalty']['customerPaidAmount'], 50);
    expect(
      () => BookingCancellation.parse({
        ...cancellationJson(),
        'refundAmount': -1,
      }, 70),
      throwsFormatException,
    );
    expect(
      () => BookingCancellation.parse({
        ...cancellationJson(),
        'refundAmount': 1.001,
      }, 70),
      throwsFormatException,
    );
    expect(
      () => BookingCancellation.parse(cancellationJson(), 71),
      throwsFormatException,
    );
  });
}
