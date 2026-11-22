import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_booking_notifications.dart';
import 'package:customer_app/features/booking/data/customer_push_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

class FakeCustomerPush implements CustomerPushGateway {
  bool available = true, permission = true;
  int deleted = 0, prompts = 0;
  String value = 'fake-device-token';
  BookingPush? initial;
  final tokenStream = StreamController<String>.broadcast();
  final messageStream = StreamController<BookingPush>.broadcast();
  @override
  Future<bool> initialize() async => available;
  @override
  Future<String?> token({bool askPermission = false}) async {
    if (askPermission) prompts++;
    return permission ? value : null;
  }

  @override
  Stream<String> get tokens => tokenStream.stream;
  @override
  Stream<BookingPush> get messages => messageStream.stream;
  @override
  Future<BookingPush?> initialMessage() async => initial;
  @override
  Future<void> deleteToken() async {
    deleted++;
  }

  void dispose() {
    tokenStream.close();
    messageStream.close();
  }
}

BookingPush push({int event = 1, bool opened = false}) => BookingPush({
  'eventId': '$event',
  'requestId': '501',
  'type': 'PROVIDER_EN_ROUTE',
  'jobId': '99999',
  'amount': '1',
}, opened: opened);

void main() {
  late BookingFixture f;
  late FakeCustomerPush gateway;
  late CustomerBookingNotifications c;
  var refreshes = 0;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    gateway = FakeCustomerPush();
    refreshes = 0;
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path == '/me/booking-devices') {
        return ResponseBody.fromString(
          jsonEncode({
            'deviceId': gateway.value == 'fake-device-token' ? 77 : 78,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (r.path.startsWith('/me/booking-devices/')) {
        return ResponseBody.fromString('', 204);
      }
      return previous(r);
    };
    c = CustomerBookingNotifications(
      f.journey.repository,
      f.f.controller,
      gateway,
      f.f.marketStore,
      onRefresh: () => refreshes++,
    );
  });
  tearDown(() {
    c.dispose();
    gateway.dispose();
    f.dispose();
  });
  test(
    'chat push opens authorized job chat without exposing message text',
    () async {
      f.requestViewBody.addAll({'status': 'CONFIRMED', 'jobId': 70});
      await c.start();
      await c.handle(
        BookingPush({
          'eventId': '90',
          'requestId': '501',
          'jobId': '70',
          'type': 'CHAT_MESSAGE_FROM_PROVIDER',
        }, opened: true),
      );
      expect(c.notice!.path, '/messages/70');
      expect(c.notice!.chat, isTrue);
    },
  );
  test(
    'registers own token without prompting and unregisters before logout',
    () async {
      await c.start();
      expect(c.deviceId, 77);
      expect(gateway.prompts, 0);
      final registration = f.f.adapter.requests.singleWhere(
        (r) => r.path == '/me/booking-devices',
      );
      expect((registration.data as Map)['token'], 'fake-device-token');
      expect(await f.f.marketStore.store.read(c.key(12)), '77');
      await f.f.controller.logout();
      final routes = f.f.adapter.requests.map((r) => r.path).toList();
      expect(routes, contains('/me/booking-devices/77'));
      expect(
        routes.indexOf('/me/booking-devices/77'),
        lessThan(routes.indexOf('/auth/logout')),
      );
      expect(gateway.deleted, greaterThan(0));
      expect(c.notice, isNull);
    },
  );
  test('denied permissions do not register; explicit permission and rotation refresh device', () async {
    gateway.permission = false;
    await c.start();
    expect(c.deviceId, isNull);
    gateway.permission = true;
    await c.enable();
    expect(gateway.prompts, 1);
    expect(c.deviceId, 77);
    gateway.value = 'rotated-token';
    await c.syncRegistration();
    expect(c.deviceId, 78);
    expect(
      f.f.adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/me/booking-devices/77',
      ),
      isTrue,
    );
  });
  test('notification uses authorized request state, deduplicates and permits subsequent tap', () async {
    f.requestViewBody.addAll({'status': 'CONFIRMED', 'jobId': 70});
    await c.start();
    await c.handle(push());
    expect(c.notice!.path, '/bookings/70');
    expect(refreshes, 1);
    await c.handle(push());
    expect(refreshes, 1);
    await c.handle(push(opened: true));
    expect(c.notice!.opened, isTrue);
    expect(refreshes, 2);
    await c.handle(push(opened: true));
    expect(refreshes, 2);
    expect(
      f.f.adapter.requests.where(
        (r) => r.method == 'POST' && r.path.contains('/booking-requests'),
      ),
      isEmpty,
    );
  });
  test('pending payment notification resolves same request rather than trusting payload money', () async {
    f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
    await c.start();
    await c.handle(push(opened: true));
    expect(c.notice!.path, '/booking-requests/501/payment');
  });
  test(
    'malformed or unowned request does not navigate or publish content',
    () async {
      await c.start();
      await c.handle(
        const BookingPush({
          'eventId': 'bad',
          'requestId': '501',
          'type': 'BOOKING_STARTED',
        }),
      );
      expect(c.notice, isNull);
      expect(refreshes, 0);
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async =>
          r.path.endsWith('/booking-requests/501')
          ? ResponseBody.fromString(
              '{}',
              404,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            )
          : previous(r);
      await c.handle(push());
      expect(c.notice, isNull);
      expect(refreshes, 0);
    },
  );
  test(
    'unconfigured Firebase leaves app usable with explicit setup feedback',
    () async {
      gateway.available = false;
      await c.start();
      await c.enable();
      expect(c.error, contains('not configured'));
      expect(c.deviceId, isNull);
      expect(
        f.f.adapter.requests.where((r) => r.path == '/me/booking-devices'),
        isEmpty,
      );
    },
  );
  test(
    'late push resolution after logout cannot publish old account data',
    () async {
      await c.start();
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/booking-requests/501')) {
          started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final action = c.handle(push());
      await started.future;
      await f.f.controller.logout();
      gate.complete();
      await action;
      expect(c.notice, isNull);
      expect(refreshes, 0);
    },
  );
  test(
    'tap arriving while foreground verification is pending is retained',
    () async {
      await c.start();
      final gate = Completer<void>(), started = Completer<void>();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/booking-requests/501')) {
          started.complete();
          await gate.future;
        }
        return previous(r);
      };
      final read = c.handle(push());
      await started.future;
      await c.handle(push(opened: true));
      gate.complete();
      await read;
      expect(c.notice!.opened, isTrue);
      expect(refreshes, 1);
    },
  );
  test(
    'failed network logout re-arms notifications for the retained session',
    () async {
      await c.start();
      final previous = f.f.adapter.extraHandler!;
      f.f.adapter.extraHandler = (r) async {
        if (r.path == '/auth/logout') {
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        return previous(r);
      };
      await f.f.controller.logout();
      await c.registration;
      expect(f.f.controller.user?.id, 12);
      expect(c.signingOut, isFalse);
      expect(c.deviceId, 77);
    },
  );
  test('storage read failure blocks registration until account binding is recovered', () async {
    f.f.marketValues.failRead = true;
    await c.start();
    await c.syncRegistration();
    expect(
      f.f.adapter.requests.where((r) => r.path == '/me/booking-devices'),
      isEmpty,
    );
    f.f.marketValues.failRead = false;
    await c.enable();
    expect(c.deviceId, 77);
  });
  test('missing session during registration reconciles auth instead of leaving cached login active', () async {
    await c.start();
    await f.f.storage.clear();
    await c.syncRegistration();
    expect(f.f.controller.user, isNull);
    expect(c.owner, isNull);
    expect(c.notice, isNull);
  });
  test(
    'another account or API binding revokes the previous delivery token',
    () async {
      await f.f.marketStore.store.write(
        'bthere.customer.push.binding.v1',
        'https://different.invalid/api/v1|12',
      );
      await c.start();
      expect(gateway.deleted, 1);
      expect(
        await f.f.marketStore.store.read('bthere.customer.push.binding.v1'),
        '${f.f.marketStore.apiScope}|12',
      );
    },
  );
}
