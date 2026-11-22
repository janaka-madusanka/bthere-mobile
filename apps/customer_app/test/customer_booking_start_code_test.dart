import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_booking_start_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;

void main() {
  late BookingFixture f;
  late CustomerBookingStartController c;
  late DateTime now;
  late Map<String, dynamic> response;
  var status = 200;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    now = clock;
    status = 200;
    f.bookings = [
      {
        ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
        'status': 'CONFIRMED',
      },
    ];
    response = {
      'purpose': 'START',
      'code': '0472',
      'expiresAt': clock.add(const Duration(minutes: 2)).toIso8601String(),
    };
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/70/verification-codes')) {
        return ResponseBody.fromString(
          jsonEncode(response),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
    c = CustomerBookingStartController(
      f.journey.repository,
      f.f.controller,
      () => now,
      f.bookings.single,
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test(
    'owned funded booking reveals exact four digit string using GET only',
    () async {
      await Future.wait([c.load(), c.load()]);
      expect(c.code, '0472');
      final requests = f.f.adapter.requests.where(
        (r) => r.path.contains('verification-codes'),
      );
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        f.f.adapter.requests.any(
          (r) =>
              r.path.endsWith('/start') ||
              r.path.endsWith('/confirm-completion'),
        ),
        isFalse,
      );
    },
  );
  test(
    'expiry and manual hiding remove secret without generating a new code',
    () async {
      await c.load();
      now = clock.add(const Duration(minutes: 3));
      expect(c.code, isNull);
      expect(c.expired, isTrue);
      c.hide();
      expect(c.expired, isFalse);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.contains('verification-codes'),
        ),
        hasLength(1),
      );
    },
  );
  test('provider start removes code on read-only lifecycle refresh', () async {
    await c.load();
    f.bookings.single['status'] = 'IN_PROGRESS';
    await c.refreshStatus();
    expect(c.code, isNull);
    expect(c.eligible, isFalse);
  });
  test(
    'fresh job state prevents fetching from a stale confirmed screen',
    () async {
      f.bookings = [
        {...f.bookings.single, 'status': 'CANCELLED'},
      ];
      await c.load();
      expect(c.code, isNull);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.contains('verification-codes'),
        ),
        isEmpty,
      );
    },
  );
  for (final invalid in ['123456', 472, '04x2', '472']) {
    test('invalid server code $invalid is never shown', () async {
      response['code'] = invalid;
      await c.load();
      expect(c.code, isNull);
      expect(c.error, isNotNull);
    });
  }
  for (final rejected in [404, 409]) {
    test(
      'HTTP $rejected renders unavailable feedback without a code',
      () async {
        status = rejected;
        response = {'detail': 'Unavailable'};
        await c.load();
        expect(c.code, isNull);
        expect(c.error, isNotNull);
      },
    );
  }
  test('unpaid requests cannot request a START code', () async {
    c.updateBooking({...f.bookings.single, 'paymentStatus': 'PENDING'});
    await c.load();
    expect(
      f.f.adapter.requests.where((r) => r.path.contains('verification-codes')),
      isEmpty,
    );
  });
  test('logout during a code read discards the late secret', () async {
    final gate = Completer<void>(), started = Completer<void>();
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.contains('verification-codes')) {
        started.complete();
        await gate.future;
      }
      return previous(r);
    };
    final load = c.load();
    await started.future;
    await f.f.controller.logout();
    gate.complete();
    await load;
    expect(c.code, isNull);
    expect(c.alive, isFalse);
  });
  test(
    'hiding while the request is in flight prevents late code revelation',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.contains('verification-codes')) {
          started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final load = c.load();
      await started.future;
      c.hide();
      gate.complete();
      await load;
      expect(c.code, isNull);
    },
  );
}
