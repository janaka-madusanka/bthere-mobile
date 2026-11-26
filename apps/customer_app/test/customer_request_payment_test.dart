import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_request_payment_controller.dart';
import 'package:customer_app/features/booking/application/customer_request_recovery.dart';
import 'package:customer_app/features/booking/data/customer_request_recovery_store.dart';
import 'package:customer_app/features/discovery/data/customer_market_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_auth_test.dart' show clock;

void main() {
  late BookingFixture f;
  late CustomerRequestPaymentController payment;
  late CustomerRequestRecoveryStore store;
  setUp(() async {
    f = BookingFixture();
    f.contextBody = contextJson(
      methods: ['WALLET', 'CARD'],
      selectionMode: 'OPEN_REQUEST',
    );
    await f.start();
    f.requestViewBody.addAll({
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
      'paymentMethod': 'WALLET',
      'paymentStatus': 'NOT_STARTED',
      'providerId': 15,
      'jobId': 70,
      'confirmationExpiresAt': clock
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    });
    store = CustomerRequestRecoveryStore(f.discovery.selectionStore, 12);
    payment = CustomerRequestPaymentController(
      501,
      f.journey.repository,
      f.f.controller,
      () => clock,
      store: store,
    );
  });
  tearDown(() {
    payment.dispose();
    f.dispose();
  });
  test('matching recovery never loads payment actions or pays before acceptance; it can cancel the same request', () async {
    f.requestViewBody['status'] = 'MATCHING';
    await payment.refresh();
    expect(payment.canPay, isFalse);
    expect(payment.canCancel, isTrue);
    expect(payment.error, isNull);
    expect(payment.window, isNull);
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/payment-window')),
      isEmpty,
    );
    await payment.pay();
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      isEmpty,
    );
    await payment.cancel();
    expect(payment.request?['status'], 'CANCELLED');
    expect(
      f.f.adapter.requests
          .where((r) => r.method == 'POST' && r.path.endsWith('/501/cancel'))
          .length,
      1,
    );
  });

  test(
    'details recover their request without waiting for a blocked event feed',
    () async {
      await store.save({500, 501});
      final blocked = Completer<void>();
      final reached = Completer<void>();
      final handler = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.uri.path.endsWith('/booking-events')) {
          if (!reached.isCompleted) reached.complete();
          await blocked.future;
        }
        return handler(r);
      };
      final recovery = CustomerRequestRecovery(
        f.journey.repository,
        f.f.controller,
        f.discovery.selectionStore,
      );
      addTearDown(recovery.dispose);
      final bulk = recovery.refresh();
      await reached.future;
      try {
        await recovery.refreshJob(70);
        expect(recovery.active.single['jobId'], 70);
        expect(recovery.active.single['canPay'], isTrue);
        expect(await store.requestForJob(70), 501);
        expect(
          await CustomerRequestRecoveryStore(
            f.discovery.selectionStore,
            99,
          ).requestForJob(70),
          isNull,
        );
      } finally {
        blocked.complete();
        await bulk;
      }
    },
  );
  test(
    'a slow old request cannot delay publishing the current payment deadline',
    () async {
      await store.save({500, 501});
      final blocked = Completer<void>();
      final reached = Completer<void>();
      final handler = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.uri.path.endsWith('/booking-requests/500')) {
          if (!reached.isCompleted) reached.complete();
          await blocked.future;
        }
        return handler(r);
      };
      final recovery = CustomerRequestRecovery(
        f.journey.repository,
        f.f.controller,
        f.discovery.selectionStore,
      );
      addTearDown(recovery.dispose);
      final bulk = recovery.refresh();
      await reached.future;
      try {
        expect(recovery.active.single['requestId'], 501);
        expect(recovery.active.single['confirmationExpiresAt'], isNotNull);
      } finally {
        blocked.complete();
        await bulk;
      }
    },
  );
  test('payment-window cannot erase the owned booking link', () async {
    await store.save({501});
    f.paymentWindowBody = {
      ...f.requestViewBody,
      'jobId': null,
      'canPay': true,
      'canCancel': true,
    };
    final recovery = CustomerRequestRecovery(
      f.journey.repository,
      f.f.controller,
      f.discovery.selectionStore,
    );
    addTearDown(recovery.dispose);
    await recovery.refreshJob(70);
    expect(recovery.active.single['jobId'], 70);
    expect(recovery.active.single['canPay'], isTrue);
  });
  test('corrupt saved references replay events instead of skipping past missing request IDs', () async {
    await store.save({501});
    await store.saveCursor(8);
    final key = f.f.marketValues.values.keys.singleWhere(
      (key) => key.contains('requests.v1.') && key.endsWith('.12'),
    );
    f.f.marketValues.values[key] = 'invalid json';
    f.requestEvents = [
      {
        'eventId': 1,
        'userId': 12,
        'requestId': 501,
        'eventType': 'PAYMENT_FAILED',
      },
    ];
    final recovery = CustomerRequestRecovery(
      f.journey.repository,
      f.f.controller,
      f.discovery.selectionStore,
    );
    addTearDown(recovery.dispose);
    await recovery.refresh();
    expect(recovery.active.single['requestId'], 501);
    expect(recovery.error, isNull);
    final events = f.f.adapter.requests.lastWhere(
      (r) => r.uri.path.endsWith('/booking-events'),
    );
    expect(events.uri.queryParameters['after'], '0');
  });
  test(
    'method switch retains accepted provider, deadline and ID without charging',
    () async {
      await payment.refresh();
      final deadline = payment.deadline;
      expect(await payment.changeMethod('CARD'), isTrue);
      expect(payment.request!['paymentMethod'], 'CARD');
      expect(await store.method(501), 'CARD');
      expect(payment.request!['providerId'], 15);
      expect(payment.deadline, deadline);
      expect(await payment.changeMethod('WALLET'), isTrue);
      expect(payment.request!['paymentMethod'], 'WALLET');
      final writes = f.f.adapter.requests.where(
        (r) => r.method == 'POST' && r.path.contains('/booking-requests/'),
      );
      expect(writes, hasLength(2));
      expect(
        writes.every((r) => r.path.endsWith('/501/payment-method')),
        isTrue,
      );
      expect(writes.first.data, {'paymentMethod': 'CARD'});
    },
  );
  test('pending and expired requests cannot switch method', () async {
    f.requestViewBody['status'] = 'PAYMENT_PENDING';
    expect(await payment.changeMethod('CARD'), isFalse);
    f.requestViewBody['status'] = 'EXPIRED';
    expect(await payment.changeMethod('CARD'), isFalse);
    expect(
      f.f.adapter.requests.where(
        (r) => r.method == 'POST' && r.path.contains('/booking-requests/'),
      ),
      isEmpty,
    );
  });
  test(
    'rejected method switch keeps method, provider and retry deadline',
    () async {
      f.methodChangeStatus = 409;
      await payment.refresh();
      final deadline = payment.deadline;
      expect(await payment.changeMethod('CARD'), isFalse);
      expect(payment.request!['paymentMethod'], 'WALLET');
      expect(payment.request!['providerId'], 15);
      expect(payment.deadline, deadline);
      expect(payment.error, contains('not enabled'));
      expect(payment.canPay, isTrue);
    },
  );
  test('server starts retry window once and restores Wallet failure after restart', () async {
    f.requestViewBody['confirmationExpiresAt'] = clock
        .add(const Duration(minutes: 2))
        .toIso8601String();
    await payment.refresh();
    expect(payment.seconds, 120);
    expect(payment.failed, isFalse);
    // Wallet 409 can keep NOT_STARTED; only the server starts the retry window.
    final retryStart = clock.add(const Duration(seconds: 45));
    f.requestViewBody.addAll({
      'paymentRetryStartedAt': retryStart.toIso8601String(),
      'confirmationExpiresAt': retryStart
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    });
    f.walletConfirmationStatus = 409;
    await payment.pay();
    expect(payment.seconds, 945);
    expect(payment.retryStartedAt, retryStart);
    await payment.pay();
    expect(payment.seconds, 945);
    payment.dispose();
    payment = CustomerRequestPaymentController(
      501,
      f.journey.repository,
      f.f.controller,
      () => clock,
      store: store,
    );
    await payment.refresh();
    expect(payment.request!['paymentStatus'], 'NOT_STARTED');
    expect(payment.failed, isTrue);
    expect(payment.canPay, isTrue);
    expect(payment.seconds, 945);
  });
  test('failed Wallet retries the same accepted request without cancellation or matching', () async {
    f.walletConfirmationStatus = 409;
    await payment.refresh();
    expect(payment.canPay, isTrue);
    await payment.pay();
    expect(payment.error, contains('Insufficient'));
    expect(payment.canPay, isTrue);
    expect(payment.request!['providerId'], 15);
    f.walletConfirmationStatus = 200;
    await payment.pay();
    expect(payment.funded, isTrue);
    final writes = f.f.adapter.requests
        .where((r) => r.method == 'POST')
        .map((r) => r.path)
        .toList();
    expect(writes.where((p) => p.endsWith('/confirm-wallet')), hasLength(2));
    expect(
      writes.where(
        (p) =>
            p.endsWith('/cancel') ||
            p.endsWith('/booking-requests') ||
            p.endsWith('/provider-search'),
      ),
      isEmpty,
    );
  });
  test(
    'server flags deny writes and provider extension updates deadline',
    () async {
      await payment.refresh();
      expect(payment.seconds, 900);
      f.paymentWindowBody = {
        'requestId': 501,
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        'paymentStatus': 'NOT_STARTED',
        'confirmationExpiresAt': clock
            .add(const Duration(minutes: 30))
            .toIso8601String(),
        'canPay': false,
        'canCancel': false,
      };
      await payment.pay();
      await payment.cancel();
      expect(payment.seconds, 1800);
      expect(payment.canPay, isFalse);
      expect(payment.canCancel, isFalse);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.path.endsWith('/confirm-wallet') || r.path.endsWith('/cancel'),
        ),
        isEmpty,
      );
    },
  );
  test('zero time blocks pay even if server flag is true', () async {
    f.requestViewBody['confirmationExpiresAt'] = clock.toIso8601String();
    await payment.refresh();
    expect(payment.seconds, 0);
    expect(payment.canPay, isFalse);
    await payment.pay();
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      isEmpty,
    );
  });
  for (final status in ['PAYMENT_PENDING', 'PAYMENT_RECONCILIATION']) {
    test('$status cannot pay or cancel despite stale action flags', () async {
      f.requestViewBody['status'] = status;
      f.paymentWindowBody = {
        ...f.requestViewBody,
        'canPay': true,
        'canCancel': true,
      };
      await payment.refresh();
      await payment.pay();
      await payment.cancel();
      expect(payment.pending, isTrue);
      expect(payment.canPay, isFalse);
      expect(payment.canCancel, isFalse);
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.path.endsWith('/confirm-wallet') || r.path.endsWith('/cancel'),
        ),
        isEmpty,
      );
    });
  }
  test(
    'missing or malformed action endpoint disables payment safely',
    () async {
      f.windowStatus = 404;
      await payment.refresh();
      await payment.pay();
      expect(payment.canPay, isFalse);
      expect(payment.error, isNotNull);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        isEmpty,
      );
    },
  );
  test('mock CARD failure retries same ID using saved methodId only', () async {
    f.requestViewBody.addAll({
      'paymentMethod': 'CARD',
      'paymentStatus': 'FAILED',
    });
    await payment.refresh();
    await payment.pay(mock: true, methodId: 5);
    expect(payment.funded, isTrue);
    final write = f.f.adapter.requests.singleWhere(
      (r) => r.path.endsWith('/confirm-mock-card'),
    );
    expect(write.data, {'methodId': 5});
    expect(payment.request!['requestId'], 501);
  });
  test(
    'unknown payment write persists uncertainty and blocks retry after restart',
    () async {
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/confirm-wallet')) {
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        return previous(r);
      };
      await payment.refresh();
      await payment.pay();
      expect(payment.pending, isTrue);
      expect(await store.uncertain(501), isTrue);
      final recovered = CustomerRequestPaymentController(
        501,
        f.journey.repository,
        f.f.controller,
        () => clock,
        store: store,
      );
      addTearDown(recovered.dispose);
      await recovered.refresh();
      await recovered.pay();
      expect(recovered.pending, isTrue);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
        hasLength(1),
      );
      f.requestViewBody['paymentStatus'] = 'FAILED';
      await recovered.refresh();
      expect(recovered.canPay, isTrue);
    },
  );
  test('events recover same request after restart and scopes separate environments/accounts', () async {
    f.requestEvents = [
      {
        'eventId': 1,
        'userId': 12,
        'requestId': 501,
        'eventType': 'PROVIDER_ACCEPTED',
      },
    ];
    final recovery = CustomerRequestRecovery(
      f.journey.repository,
      f.f.controller,
      f.discovery.selectionStore,
    );
    await recovery.refresh();
    expect(recovery.active.single['requestId'], 501);
    recovery.dispose();
    final again = CustomerRequestRecovery(
      f.journey.repository,
      f.f.controller,
      f.discovery.selectionStore,
    );
    addTearDown(again.dispose);
    f.requestEvents = [];
    await again.refresh();
    expect(again.active.single['requestId'], 501);
    expect(
      await CustomerRequestRecoveryStore(f.discovery.selectionStore, 99).read(),
      isEmpty,
    );
    expect(
      await CustomerRequestRecoveryStore(
        CustomerMarketSelectionStore(
          f.f.marketValues,
          apiScope: 'https://other.invalid',
        ),
        12,
      ).read(),
      isEmpty,
    );
    await f.f.controller.logout();
    expect(again.active, isEmpty);
    expect(payment.alive, isFalse);
  });
  test('local storage failure cannot hide server recovered payment deadline and action', () async {
    f.requestEvents = [
      {
        'eventId': 1,
        'userId': 12,
        'requestId': 501,
        'eventType': 'PAYMENT_FAILED',
      },
    ];
    f.requestViewBody['paymentRetryStartedAt'] = clock.toIso8601String();
    f.f.marketValues.failRead = true;
    f.f.marketValues.failWrite = true;
    final recovery = CustomerRequestRecovery(
      f.journey.repository,
      f.f.controller,
      f.discovery.selectionStore,
    );
    addTearDown(recovery.dispose);
    await recovery.refresh();
    expect(recovery.error, isNull);
    expect(recovery.active.single['jobId'], 70);
    expect(recovery.active.single['canPay'], isTrue);
    expect(recovery.active.single['confirmationExpiresAt'], isNotNull);
    f.requestEvents = [];
    await recovery.refresh();
    expect(recovery.active.single['requestId'], 501);
    // Failed persistence must not advance the durable event cursor.
    f.f.marketValues.failRead = false;
    expect(await store.cursor(), 0);
  });
  test(
    'method absent from View restores saved selection without guessing',
    () async {
      await store.saveMethod(501, 'WALLET');
      f.requestViewBody.remove('paymentMethod');
      await payment.refresh();
      expect(payment.request!['paymentMethod'], 'WALLET');
      expect(payment.canPay, isTrue);
    },
  );
  test('late reads after logout cannot restore another account data', () async {
    final pending = Completer<void>();
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path == '/customers/me/booking-requests/501') await pending.future;
      return previous(r);
    };
    final read = payment.refresh();
    await Future<void>.delayed(Duration.zero);
    await f.f.controller.logout();
    pending.complete();
    await read;
    expect(payment.request, isNull);
    expect(payment.canPay, isFalse);
  });
  test(
    'hosted retry preserves request, validates signed amount and pending state',
    () async {
      f.requestViewBody.addAll({
        'paymentMethod': 'CARD',
        'paymentStatus': 'FAILED',
      });
      (f.cardCheckoutBody['fields'] as Map)['amount'] = '1000.00';
      final checkout = await payment.pay(
        cardBrand: 'VISA',
        email: 'test@example.com',
        phone: '+94771234567',
      );
      expect(checkout, isNotNull);
      expect(payment.pending, isTrue);
      final request = f.f.adapter.requests.singleWhere(
        (r) => r.path.endsWith('/confirm'),
      );
      expect((request.data as Map).keys, isNot(contains('amount')));
      expect(jsonEncode(request.data), isNot(contains('methodId')));
    },
  );
  test('a stale failed state cannot unlock an uncertain new attempt', () async {
    f.requestViewBody['paymentStatus'] = 'FAILED';
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/confirm-wallet')) {
        throw const NetworkException(
          kind: NetworkExceptionKind.timeout,
          message: 'Timeout',
        );
      }
      return previous(r);
    };
    await payment.refresh();
    await payment.pay();
    expect(payment.pending, isTrue);
    await payment.refresh();
    await payment.pay();
    expect(payment.canPay, isFalse);
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      hasLength(1),
    );
    f.requestViewBody['status'] = 'PAYMENT_RECONCILIATION';
    await payment.refresh();
    f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
    await payment.refresh();
    expect(payment.canPay, isTrue);
  });
  test('concurrent pay taps await a background read then write once', () async {
    final gate = Completer<void>();
    final previous = f.f.adapter.extraHandler!;
    var waiting = true;
    f.f.adapter.extraHandler = (r) async {
      if (r.path == '/customers/me/booking-requests/501' && waiting) {
        await gate.future;
      }
      return previous(r);
    };
    final read = payment.refresh(background: true);
    final first = payment.pay();
    final second = payment.pay();
    waiting = false;
    gate.complete();
    await Future.wait([read, first, second]);
    expect(payment.funded, isTrue);
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      hasLength(1),
    );
  });
}
