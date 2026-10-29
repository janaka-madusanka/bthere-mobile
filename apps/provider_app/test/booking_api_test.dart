import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/bookings/data/booking_repository.dart';
import 'package:provider_app/features/bookings/domain/booking_models.dart';
import 'package:provider_app/features/wallet/domain/wallet_models.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'support/fake_session_storage.dart';

Map<String, dynamic> offerJson({String status = 'PENDING'}) => {
  'offerId': 601,
  'requestId': 501,
  'status': status,
  'expiresAt': '2030-01-02T12:01:00Z',
  'serviceTypeId': 3,
  'optionId': 12,
  'deliveryMode': 'PROVIDER_TO_CUSTOMER',
  'requestedPickupTime': '2030-01-07T08:00:00',
  'currencyCode': 'LKR',
  'expectedAmount': 1000,
  'platformFee': 150,
  'providerEarnings': 850,
  'pickup': {'address': 'Colombo'},
};
Map<String, dynamic> bookingJson({
  String status = 'AWAITING_PAYMENT',
  String payment = 'NOT_STARTED',
}) => {
  'jobId': 70,
  'serviceTypeId': 3,
  'status': status,
  'paymentStatus': payment,
  'currencyCode': 'LKR',
  'providerEarnings': 850,
  'answers': [],
};

void main() {
  test('only a confirmed paid booking can start', () {
    for (final status in [
      'BOOKING_CONFIRMED',
      'AWAITING_PAYMENT',
      'AWAITING_CUSTOMER_CONFIRMATION',
      'IN_PROGRESS',
      'AWAITING_COMPLETION_CONFIRMATION',
      'COMPLETED',
      'CANCELLED',
      'EXPIRED',
      'UNMATCHED',
      'UNKNOWN',
    ]) {
      for (final payment in ['PAID', 'SETTLED', 'NOT_STARTED', 'FAILED']) {
        expect(
          AssignedBooking.fromJson(
            bookingJson(status: status, payment: payment),
          ).canStart,
          status == 'BOOKING_CONFIRMED' &&
              ['PAID', 'SETTLED'].contains(payment),
          reason: '$status / $payment',
        );
      }
    }
  });
  test(
    'assigned details retain configuration, pricing and customer answers',
    () {
      final json = bookingJson()
        ..addAll({
          'optionId': 12,
          'providerIds': [15],
          'schedulingModel': 'TIME_BASED',
          'providerLocationId': 9,
          'destinationAddress': 'Destination address',
          'platformFeePercentage': 15,
          'platformFee': 150,
          'pricingSelections': {'duration': 2},
          'pricingSnapshot': {'rateId': 4},
          'answers': [
            {'fieldId': 1, 'value': 'Submitted answer'},
          ],
        });
      final booking = AssignedBooking.fromJson(json);
      expect(booking.details['providerIds'], [15]);
      expect(booking.details['providerLocationId'], 9);
      expect(booking.details['destinationAddress'], 'Destination address');
      expect(booking.pricingSelections, {'duration': 2});
      expect(booking.pricingSnapshot, {'rateId': 4});
      expect(booking.answers, json['answers']);
      expect(booking.earningsLabel, "You'll earn LKR 850.00");
    },
  );
  test('net earnings retain decimal precision at the JSON boundary', () {
    final decoded = decodeWalletJson('{"providerEarnings":99999999999999.99}');
    expect((decoded as Map)['providerEarnings'], '99999999999999.99');
    expect(
      WalletMoney.parse(decoded['providerEarnings']).decimal,
      '99999999999999.99',
    );
  });
  late RegistrationAdapter adapter;
  late ApiClient client;
  late BookingRepository repository;
  setUp(() {
    adapter = RegistrationAdapter();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
    );
    repository = BookingRepository(client);
  });
  tearDown(() => client.close(force: true));
  test(
    'pending offers use provider auth and net earnings, UTC expiry',
    () async {
      adapter.responses['/providers/me/booking-offers'] = [offerJson()];
      final offer = (await repository.offers()).single;
      expect(offer.earningsLabel, "You'll earn LKR 850.00");
      expect(offer.pendingAt(testNow), isTrue);
      expect(offer.pendingAt(offer.expiresAt), isFalse);
      expect(
        BookingOffer.fromJson(offerJson(status: 'CANCELLED'))
            .pendingAt(testNow),
        isFalse,
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic-access',
      );
    },
  );
  test(
    'accept and decline have no body, assigned details use returned job ID',
    () async {
      for (final accept in [true, false]) {
        final path =
            '/providers/me/booking-offers/601/${accept ? 'accept' : 'decline'}';
        adapter.responses[path] = {
          'requestId': 501,
          'jobId': accept ? 70 : null,
          'status': accept ? 'AWAITING_CUSTOMER_CONFIRMATION' : 'DECLINED',
        };
        final decision = await repository.decide(601, accept: accept);
        expect(decision.jobId, accept ? 70 : null);
        expect(adapter.requests.last.data, isNull);
        expect(adapter.requests.last.method, 'POST');
      }
      adapter.responses['/providers/me/bookings/70'] = bookingJson();
      expect((await repository.booking(70)).canStart, isFalse);
    },
  );
  test(
    'start code is validated; complete sends neither code nor body',
    () async {
      await expectLater(repository.start(70, 'bad'), throwsFormatException);
      expect(adapter.requests, isEmpty);
      adapter.responses['/providers/me/bookings/70/start'] = {
        'successful': false,
        'status': 'INVALID_CODE',
      };
      expect((await repository.start(70, '123456')).successful, isFalse);
      expect(adapter.requests.single.data, {'code': '123456'});
      adapter.responses['/providers/me/bookings/70/complete'] = {
        'successful': true,
        'status': 'AWAITING_COMPLETION_CONFIRMATION',
      };
      expect(
        (await repository.complete(70)).status,
        'AWAITING_COMPLETION_CONFIRMATION',
      );
      expect(adapter.requests.last.data, isNull);
      expect(
        AssignedBooking.fromJson(
          bookingJson(status: 'IN_PROGRESS', payment: 'PAID'),
        ).canComplete,
        isTrue,
      );
      final waiting = AssignedBooking.fromJson(
        bookingJson(
          status: 'AWAITING_COMPLETION_CONFIRMATION',
          payment: 'PAID',
        ),
      );
      expect(waiting.completed, isFalse);
      expect(waiting.canComplete, isFalse);
    },
  );
  test(
    'event cursor and booking device contracts are provider authenticated',
    () async {
      adapter.responses['/providers/me/booking-events'] = [
        {'eventId': 21, 'requestId': 501, 'eventType': 'OFFER_CANCELLED'},
      ];
      expect((await repository.events(20)).single.type, 'OFFER_CANCELLED');
      expect(adapter.requests.last.queryParameters, {'after': 20});
      adapter.responses['/me/booking-devices'] = {'deviceId': 8};
      expect(
        await repository.registerDevice(
          token: 'synthetic-device',
          platform: 'ANDROID',
          deviceName: 'Test',
        ),
        8,
      );
      await repository.unregisterDevice(8);
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.data, isNull);
      await expectLater(repository.events(-1), throwsFormatException);
      await expectLater(
        repository.registerDevice(
          token: 'x',
          platform: 'WEB',
          deviceName: 'Test',
        ),
        throwsFormatException,
      );
      expect(
        adapter.requests.every(
          (r) => !r.path.contains('/customers/') && !r.path.contains('/admin/'),
        ),
        isTrue,
      );
    },
  );
  test('earnings history tolerates legacy metadata and keeps settlement references', () {
    final entry = WalletEntry.fromJson({
      'entryId': 1,
      'operationId': 2,
      'bucket': 'AVAILABLE',
      'delta': 850,
      'balanceBefore': 0,
      'balanceAfter': 850,
      'createdAt': '2026-10-25T10:30:00',
      'type': 'CARD_BOOKING_SETTLE',
      'jobId': 70,
      'providerEarnings': 850,
      'fundingMode': 'PAYHERE_SANDBOX',
    });
    expect(entry.jobId, 70);
    expect(entry.providerEarnings!.decimal, '850.00');
    expect(entry.currency, 'LKR');
  });
}
