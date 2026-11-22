import 'dart:async';

import 'package:customer_app/features/booking/application/customer_booking_progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

void main() {
  late BookingFixture f;
  late CustomerBookingProgressController c;
  var changes = 0;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    changes = 0;
    f.bookings = [
      {
        ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
        'status': 'CONFIRMED',
      },
    ];
    c = CustomerBookingProgressController(
      f.journey.repository,
      f.f.controller,
      {...f.bookings.single},
      onChanged: () => changes++,
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test(
    'timestamp corrections notify details even when status does not change',
    () async {
      f.bookings = [
        {...f.bookings.single, 'actualStartedAt': '2026-11-20T08:00:00Z'},
      ];
      await c.refresh();
      expect(changes, 1);
      expect(c.booking['actualStartedAt'], '2026-11-20T08:00:00Z');
      await c.refresh();
      expect(changes, 1);
    },
  );
  test(
    'only authoritative server states advance progress, terminal stops polling',
    () async {
      await c.refresh();
      expect(changes, 0);
      for (final status in [
        'IN_PROGRESS',
        'AWAITING_COMPLETION_CONFIRMATION',
        'COMPLETED',
      ]) {
        f.bookings = [
          {...f.bookings.single, 'status': status},
        ];
        await c.refresh();
        expect(c.booking['status'], status);
      }
      expect(changes, 3);
      final count = f.f.adapter.requests.length;
      await c.refresh();
      expect(f.f.adapter.requests.length, count);
      expect(
        f.f.adapter.requests
            .where((r) => r.path.contains('/bookings'))
            .every((r) => r.method == 'GET'),
        isTrue,
      );
    },
  );
  test('unchanged background reads do not notify or reset UI', () async {
    var notifications = 0;
    c.addListener(() => notifications++);
    await c.refresh();
    await c.refresh();
    expect(notifications, 0);
    expect(changes, 0);
  });
  test('missing booking retains last state and recovers on the next successful read', () async {
    final booking = {...f.bookings.single};
    f.bookings = [];
    await c.refresh();
    expect(c.booking['status'], 'CONFIRMED');
    expect(c.error, isNotNull);
    f.bookings = [
      {...booking, 'status': 'IN_PROGRESS'},
    ];
    await c.refresh();
    expect(c.error, isNull);
    expect(c.booking['status'], 'IN_PROGRESS');
  });
  test(
    'overlapping reads are skipped and logout discards the result',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      var calls = 0;
      f.f.adapter.extraHandler = (r) async {
        if (r.path == '/customers/me/bookings') {
          calls++;
          started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final read = c.refresh();
      await started.future;
      await c.refresh();
      expect(calls, 1);
      await f.f.controller.logout();
      gate.complete();
      await read;
      expect(c.alive, isFalse);
      expect(c.booking, isEmpty);
      expect(changes, 0);
    },
  );
}
