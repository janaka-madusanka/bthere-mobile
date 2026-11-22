import 'dart:convert';
import 'dart:async';

import 'package:customer_app/features/booking/domain/booking_card_checkout.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';

void main() {
  test(
    'repeated confirm clicks do not start concurrent card checkouts',
    () async {
      final f = BookingFixture();
      addTearDown(f.dispose);
      await f.start();
      final c = f.journey;
      f.requestViewBody.addAll({
        'paymentMethod': 'CARD',
        'status': 'AWAITING_CUSTOMER_CONFIRMATION',
      });
      c.created = {...f.requestViewBody};
      c.stage = BookingStage.created;
      f.pendingCardConfirmation = Completer<void>();
      final first = c.confirmRequestCard(
        'VISA',
        billingEmail: 'test@example.com',
        billingPhone: '+94771234567',
      );
      await f.cardConfirmationReached.future;
      expect(await c.confirmRequestCard('VISA'), isNull);
      f.pendingCardConfirmation!.complete();
      expect(await first, isNotNull);
      expect(
        f.f.adapter.requests.where((r) => r.path.endsWith('/501/confirm')),
        hasLength(1),
      );
    },
  );

  test('expired card acceptance is read again and never confirmed', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    f.requestViewBody.addAll({
      'paymentMethod': 'CARD',
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
      'confirmationExpiresAt': c
          .now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    });
    c.created = {...f.requestViewBody};
    c.stage = BookingStage.created;
    expect(
      await c.confirmRequestCard(
        'VISA',
        billingEmail: 'test@example.com',
        billingPhone: '+94771234567',
      ),
      isNull,
    );
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/501/confirm')),
      isEmpty,
    );
    expect(c.error, contains('expired'));
  });
  test(
    'hosted checkout POST preserves every signed field and callback queries',
    () {
      final f = BookingFixture();
      final fields = f.cardCheckoutBody['fields'] as Map<String, String>;
      fields['return_url'] = 'https://example.invalid/return?request=501';
      fields['unicode'] = 'සිංහල & + " <test>';
      final checkout = BookingCardCheckout.parse(f.cardCheckoutBody);
      expect(Uri.splitQueryString(utf8.decode(checkout.body)), fields);
      expect(
        checkout.isReturn(
          Uri.parse(
            'https://example.invalid/return?request=501&status=success',
          ),
        ),
        isTrue,
      );
      expect(
        checkout.isReturn(
          Uri.parse('https://example.invalid/return?request=502'),
        ),
        isFalse,
      );
      expect(
        checkout.isReturn(
          Uri.parse('https://other.invalid/return?request=501'),
        ),
        isFalse,
      );
    },
  );

  for (final url in [
    'http://sandbox.payhere.lk/pay/checkout',
    'https://sandbox.payhere.lk.evil.invalid/pay/checkout',
    'https://user:password@sandbox.payhere.lk/pay/checkout',
    'https://sandbox.payhere.lk:444/pay/checkout',
    'https://sandbox.payhere.lk/other',
  ]) {
    test('rejects unexpected checkout destination $url', () {
      final f = BookingFixture();
      f.cardCheckoutBody['actionUrl'] = url;
      expect(
        () => BookingCardCheckout.parse(f.cardCheckoutBody),
        throwsFormatException,
      );
    });
  }

  test('card confirmation uses the request contract and waits for verified callback', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    f.requestViewBody.addAll({
      'paymentMethod': 'CARD',
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
    });
    c.created = {...f.requestViewBody};
    c.stage = BookingStage.created;
    final checkout = await c.confirmRequestCard(
      'VISA',
      billingEmail: 'test@example.com',
      billingPhone: '+94771234567',
    );
    expect(checkout, isNotNull);
    expect(c.created?['status'], 'PAYMENT_PENDING');
    expect(c.paymentOutcome, isNull);
    final call = f.f.adapter.requests.singleWhere(
      (r) => r.path.endsWith('/501/confirm'),
    );
    expect(call.method, 'POST');
    expect(
      (call.data as Map).keys,
      unorderedEquals([
        'cardMethod',
        'firstName',
        'lastName',
        'email',
        'phone',
        'address',
        'city',
        'country',
      ]),
    );
    expect((call.data as Map)['cardMethod'], 'VISA');
    f.requestViewBody.addAll({
      'status': 'CONFIRMED',
      'paymentStatus': 'PAID',
      'jobId': 70,
    });
    await c.refreshCreatedRequest();
    expect(c.paymentOutcome, 'SUCCESS');
  });

  for (final status in [402, 503]) {
    test(
      'card confirmation $status does not report success or automatically retry',
      () async {
        final f = BookingFixture();
        addTearDown(f.dispose);
        await f.start();
        final c = f.journey;
        f.cardConfirmationStatus = status;
        f.requestViewBody.addAll({
          'paymentMethod': 'CARD',
          'status': 'AWAITING_CUSTOMER_CONFIRMATION',
        });
        c.created = {...f.requestViewBody};
        c.stage = BookingStage.created;
        expect(
          await c.confirmRequestCard(
            'MASTER',
            billingEmail: 'test@example.com',
            billingPhone: '+94771234567',
          ),
          isNull,
        );
        expect(c.error, isNotNull);
        expect(c.paymentOutcome, status == 402 ? 'FAILURE' : isNull);
        expect(
          c.created?['status'],
          status == 503 ? 'PAYMENT_PENDING' : 'AWAITING_CUSTOMER_CONFIRMATION',
        );
        expect(
          f.f.adapter.requests.where((r) => r.path.endsWith('/501/confirm')),
          hasLength(1),
        );
      },
    );
  }

  test('mismatched signed amount never opens checkout', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    (f.cardCheckoutBody['fields'] as Map)['amount'] = '999.00';
    f.requestViewBody.addAll({
      'paymentMethod': 'CARD',
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
    });
    c.created = {...f.requestViewBody};
    c.stage = BookingStage.created;
    expect(
      await c.confirmRequestCard(
        'VISA',
        billingEmail: 'test@example.com',
        billingPhone: '+94771234567',
      ),
      isNull,
    );
    expect(c.created?['status'], 'PAYMENT_PENDING');
    expect(c.paymentOutcome, isNull);
  });
}
