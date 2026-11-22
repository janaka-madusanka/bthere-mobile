import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_booking_progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

void main() {
  late BookingFixture f;
  late CustomerBookingProgressController c;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    f.bookings = [
      {
        ...bookingJson(id: 70, method: 'WALLET', payment: 'RESERVED'),
        'status': 'AWAITING_COMPLETION_CONFIRMATION',
      },
    ];
    c = CustomerBookingProgressController(
      f.journey.repository,
      f.f.controller,
      {...f.bookings.single},
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test('explicit completion submits once with no payment body and reads settled job', () async {
    final results = await Future.wait([
      c.confirmCompletion(),
      c.confirmCompletion(),
    ]);
    expect(results.where((value) => value), hasLength(1));
    expect(c.booking['status'], 'COMPLETED');
    expect(c.booking['paymentStatus'], 'SETTLED');
    final posts = f.f.adapter.requests.where(
      (r) => r.path.endsWith('/confirm-completion'),
    );
    expect(posts, hasLength(1));
    expect(posts.single.data, isNull);
    expect(c.canConfirmCompletion, isFalse);
    await c.confirmCompletion();
    expect(posts, hasLength(1));
  });
  test(
    'Card PAID can confirm completion without another card checkout',
    () async {
      f.bookings = [
        {
          ...f.bookings.single,
          'paymentMethod': 'CARD',
          'paymentStatus': 'PAID',
        },
      ];
      c.updateBooking(f.bookings.single);
      expect(await c.confirmCompletion(), isTrue);
      expect(c.booking['paymentStatus'], 'SETTLED');
      expect(
        f.f.adapter.requests.any(
          (r) =>
              r.path.endsWith('/confirm') || r.path.endsWith('/confirm-wallet'),
        ),
        isFalse,
      );
    },
  );
  test(
    'fresh state prevents stale waiting UI from confirming an in-progress job',
    () async {
      f.bookings = [
        {...f.bookings.single, 'status': 'IN_PROGRESS'},
      ];
      expect(await c.confirmCompletion(), isFalse);
      expect(c.booking['status'], 'IN_PROGRESS');
      expect(
        f.f.adapter.requests.any((r) => r.path.endsWith('/confirm-completion')),
        isFalse,
      );
    },
  );
  test('unpaid or merely confirmed job cannot confirm completion', () async {
    c.updateBooking({...c.booking, 'paymentStatus': 'PENDING'});
    expect(await c.confirmCompletion(), isFalse);
    c.updateBooking({
      ...c.booking,
      'paymentStatus': 'RESERVED',
      'status': 'CONFIRMED',
    });
    expect(await c.confirmCompletion(), isFalse);
    expect(
      f.f.adapter.requests.any((r) => r.path.endsWith('/confirm-completion')),
      isFalse,
    );
  });
  test('settlement rejection retains awaiting state and visible error for explicit retry', () async {
    f.completionStatus = 409;
    expect(await c.confirmCompletion(), isFalse);
    expect(c.booking['status'], 'AWAITING_COMPLETION_CONFIRMATION');
    expect(c.completionError, contains('could not be posted'));
    expect(c.canConfirmCompletion, isTrue);
  });
  test(
    'unknown result reconciles by GET without automatic confirmation retry',
    () async {
      var timeout = true;
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/confirm-completion') && timeout) {
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        return previous(r);
      };
      expect(await c.confirmCompletion(), isFalse);
      expect(c.completionError, isNotNull);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/confirm-completion'),
        ),
        hasLength(1),
      );
      timeout = false;
      expect(await c.confirmCompletion(), isTrue);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/confirm-completion'),
        ),
        hasLength(2),
      );
    },
  );
  test(
    'completion acknowledgement does not roll back on stale history',
    () async {
      final old = {...f.bookings.single};
      var posted = false, stale = true;
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/confirm-completion')) posted = true;
        if (r.path == '/customers/me/bookings' && posted && stale) {
          stale = false;
          return ResponseBody.fromString(
            jsonEncode([old]),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return previous(r);
      };
      expect(await c.confirmCompletion(), isTrue);
      expect(c.booking['status'], 'COMPLETED');
      expect(c.canConfirmCompletion, isFalse);
      await c.refresh();
      expect(c.booking['paymentStatus'], 'SETTLED');
    },
  );
  test(
    'completion waits for background read and never swallows the tap',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path == '/customers/me/bookings') {
          if (!started.isCompleted) started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final read = c.refresh();
      await started.future;
      final confirm = c.confirmCompletion();
      gate.complete();
      await read;
      expect(await confirm, isTrue);
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/confirm-completion'),
        ),
        hasLength(1),
      );
    },
  );
  test(
    'logout while confirmation is in flight discards its late result',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/confirm-completion')) {
          started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final confirm = c.confirmCompletion();
      await started.future;
      await f.f.controller.logout();
      gate.complete();
      await confirm;
      expect(c.alive, isFalse);
      expect(c.booking, isEmpty);
    },
  );
}
