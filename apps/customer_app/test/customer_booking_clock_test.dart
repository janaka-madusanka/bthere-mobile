import 'package:customer_app/app/customer_booking_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server Date corrects device skew and advances independently of phone clock', () {
    var device = DateTime.utc(2026, 11, 25, 4, 40);
    var elapsed = Duration.zero;
    final clock = CustomerBookingClock(() => device, elapsed: () => elapsed);
    expect(clock.now(), device);
    clock.synchronize('Wed, 25 Nov 2026 04:30:00 GMT');
    expect(clock.now(), DateTime.utc(2026, 11, 25, 4, 30));
    device = device.add(const Duration(hours: 5));
    elapsed = const Duration(seconds: 12);
    expect(clock.now(), DateTime.utc(2026, 11, 25, 4, 30, 12));
    clock.synchronize('invalid');
    clock.synchronize(null);
    expect(clock.now(), DateTime.utc(2026, 11, 25, 4, 30, 12));
  });
}
