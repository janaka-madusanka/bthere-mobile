import 'package:customer_app/features/booking/domain/booking_auto_cancel.dart';
import 'package:customer_app/features/booking/domain/booking_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_cancellation_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 25, 5);
  final waiting = <String, dynamic>{
    'status': 'CONFIRMED',
    'startDatetimeUtc': '2026-11-25T04:30:00Z',
    'autoCancelAt': '2026-11-25T05:30:00Z',
    'autoCancelHold': null,
  };
  test('only backend deadline determines grace; pre-start and old bookings stay hidden', () {
    expect(bookingAutoCancelState(waiting, now), AutoCancelState.cancelsSoon);
    expect(
      bookingAutoCancelState(waiting, now.subtract(const Duration(hours: 1))),
      AutoCancelState.none,
    );
    expect(
      bookingAutoCancelState({...waiting, 'autoCancelAt': null}, now),
      AutoCancelState.none,
    );
    expect(
      bookingAutoCancelState({
        ...waiting,
        'autoCancelAt': '2026-11-25T05:30:00',
      }, now),
      AutoCancelState.none,
    );
    expect(
      autoCancelInstant('2026-11-25T11:00:00+05:30'),
      DateTime.utc(2026, 11, 25, 5, 30),
    );
  });
  test('holds follow server and deadline expiry takes precedence without cancelling locally', () {
    expect(
      bookingAutoCancelState({
        ...waiting,
        'autoCancelHold': 'PROVIDER_ARRIVED',
      }, now),
      AutoCancelState.heldArrived,
    );
    expect(
      bookingAutoCancelState({
        ...waiting,
        'autoCancelHold': 'START_CODE_TRIED',
      }, now),
      AutoCancelState.heldCodeTried,
    );
    expect(
      bookingAutoCancelState(waiting, DateTime.utc(2026, 11, 25, 5, 30)),
      AutoCancelState.overdue,
    );
    expect(waiting['status'], 'CONFIRMED');
  });
  test('started, review, completed, unpaid and manual cancellation never show auto-cancel', () {
    for (final status in [
      'IN_PROGRESS',
      'AWAITING_COMPLETION_CONFIRMATION',
      'COMPLETED',
      'NO_SHOW_REVIEW',
      'AWAITING_PAYMENT',
      'CANCELLED',
    ]) {
      expect(
        bookingAutoCancelState({...waiting, 'status': status}, now),
        AutoCancelState.none,
      );
    }
    expect(
      bookingAutoCancelState({
        ...waiting,
        'actualStartedAt': now.toIso8601String(),
      }, now),
      AutoCancelState.none,
    );
    expect(
      bookingAutoCancelState({
        ...waiting,
        'status': 'CANCELLED',
        'cancellation': {'automatic': true, 'cancelledBy': 'SYSTEM'},
      }, now),
      AutoCancelState.autoCancelled,
    );
  });
  test('system full refund receipt parses and preserves backend amounts', () {
    final row = {
      ...cancellationJson(receipt: true, by: 'SYSTEM'),
      'paidAmount': 5000,
      'refundAmount': 5000,
      'cancellationFee': 0,
      'paymentStatus': 'REFUNDED',
      'reason': 'PROVIDER_DID_NOT_START',
    };
    expect(BookingCancellation.parse(row, 70, receipt: true).refund, 5000);
    expect(
      () => BookingCancellation.parse(
        {...row, 'refundAmount': 6000},
        70,
        receipt: true,
      ),
      throwsFormatException,
    );
  });
}
