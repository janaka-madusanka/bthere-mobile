import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_tracking_status_controller.dart';
import 'package:customer_app/features/booking/domain/booking_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

Map<String, dynamic> trackingJson({
  String status = 'NOT_STARTED',
  String mode = 'FULL_TRIP',
  int interval = 4,
}) => {
  'jobId': 70,
  'jobStatus': 'CONFIRMED',
  'status': status,
  'mode': mode,
  'pollIntervalSeconds': interval,
};

class TrackingBackend {
  Map<String, dynamic> body = trackingJson();
  int status = 200, calls = 0;
  Completer<void>? gate, started;
  void install(BookingFixture f) {
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/bookings/70/tracking')) {
        calls++;
        final result = {...body};
        if (gate != null) {
          started?.complete();
          await gate!.future;
        }
        return ResponseBody.fromString(
          jsonEncode(result),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return previous(r);
    };
  }
}

void main() {
  late BookingFixture f;
  late TrackingBackend backend;
  late CustomerTrackingStatusController c;
  setUp(() async {
    f = BookingFixture();
    await f.start();
    backend = TrackingBackend()..install(f);
    c = CustomerTrackingStatusController(
      f.journey.repository,
      f.f.controller,
      70,
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  test(
    'journey transitions come only from GET and keep the server interval',
    () async {
      for (final status in [
        'NOT_STARTED',
        'EN_ROUTE',
        'ARRIVED',
        'IN_TRIP',
        'ENDED',
      ]) {
        backend.body = trackingJson(status: status, interval: 7);
        await c.refresh();
        expect(c.status!.status, status);
        expect(c.status!.pollSeconds, 7);
      }
      expect(c.polls, isFalse);
      expect(
        f.f.adapter.requests
            .where((r) => r.path.endsWith('/tracking'))
            .every((r) => r.method == 'GET'),
        isTrue,
      );
    },
  );
  test('unchanged responses do not refresh visible UI; failures retain last status', () async {
    await c.refresh();
    var changed = 0;
    c.addListener(() => changed++);
    await c.refresh();
    expect(changed, 0);
    backend.status = 503;
    await c.refresh();
    expect(c.status!.status, 'NOT_STARTED');
    expect(c.error, isNotNull);
    backend.status = 200;
    await c.refresh();
    expect(c.error, isNull);
  });
  test(
    'missing/unowned tracking pauses automatic reads until explicit retry',
    () async {
      await c.refresh();
      backend.status = 404;
      await c.refresh();
      expect(c.polls, isFalse);
      expect(c.error, isNotNull);
      backend.status = 200;
      await c.refresh();
      expect(c.polls, isTrue);
    },
  );
  test(
    'overlapping reads are ignored and logout discards pending status',
    () async {
      backend.gate = Completer<void>();
      backend.started = Completer<void>();
      final read = c.refresh();
      await backend.started!.future;
      await c.refresh();
      expect(backend.calls, 1);
      await f.f.controller.logout();
      backend.gate!.complete();
      await read;
      expect(c.alive, isFalse);
      expect(c.status, isNull);
    },
  );
  test(
    'terminal modes stop polling and malformed/mismatched data is rejected',
    () {
      expect(
        BookingTrackingStatus.parse(
          trackingJson(status: 'NOT_SUPPORTED'),
          70,
        ).polls,
        isFalse,
      );
      expect(
        BookingTrackingStatus.parse(
          trackingJson(status: 'ARRIVED', mode: 'TO_SERVICE'),
          70,
        ).polls,
        isFalse,
      );
      expect(
        () => BookingTrackingStatus.parse({...trackingJson(), 'jobId': 71}, 70),
        throwsFormatException,
      );
      expect(
        () => BookingTrackingStatus.parse(trackingJson(status: 'INVENTED'), 70),
        throwsFormatException,
      );
      expect(
        () => BookingTrackingStatus.parse(trackingJson(interval: 0), 70),
        throwsFormatException,
      );
      expect(
        () => BookingTrackingStatus.parse(
          trackingJson(status: 'IN_TRIP', mode: 'NONE'),
          70,
        ),
        throwsFormatException,
      );
    },
  );
}
