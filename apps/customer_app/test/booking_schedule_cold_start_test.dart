import 'package:customer_app/features/booking/presentation/booking_details_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UTC fields take precedence over local times and selected timezone', () {
    for (final key in ['startDatetimeUtc', 'startAtUtc']) {
      expect(
        bookingScheduledInstant({
          key: '2026-11-25T04:30:00Z',
          'startDatetime': '2026-11-25T10:00:00',
        }, 'America/New_York'),
        DateTime.utc(2026, 11, 25, 4, 30),
      );
    }
    expect(
      bookingScheduledInstant({
        'startDatetimeUtc': 'not-a-date',
        'startDatetime': '2026-11-25T10:00:00',
        'marketTimezone': 'Asia/Colombo',
      }, null),
      DateTime.utc(2026, 11, 25, 4, 30),
    );
  });
  test('booking history resolves market schedule before opening a booking form', () {
    // Intentionally do not initialize timezone data: this is the cold-start
    // history path, which must not depend on a previous booking-context parse.
    expect(
      bookingScheduledInstant({
        'startDatetime': '2026-12-18T08:30:00',
      }, 'Asia/Colombo'),
      DateTime.utc(2026, 12, 18, 3),
    );
    expect(
      bookingScheduledInstant({'startDatetime': '2026-12-18T08:30:00'}, null),
      isNull,
    );
    expect(
      bookingScheduledInstant({
        'startDatetime': '2026-12-18T08:30:00',
      }, 'Unknown/Zone'),
      isNull,
    );
  });
}
