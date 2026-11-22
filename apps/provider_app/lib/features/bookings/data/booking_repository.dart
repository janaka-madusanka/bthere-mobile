import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../domain/booking_models.dart';
import '../../wallet/domain/wallet_models.dart' show decodeWalletJson;

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
  dependencies: [apiClientProvider],
);

/// Provider operations from the 25 October 2026 contract. Base URL includes /api/v1.
class BookingRepository {
  BookingRepository(this.client);
  final ApiClient client;
  static const _base = '/providers/me';
  Future<Object?> _readMoney(String path) async => decodeWalletJson(
    (await client.get<String>(
      path,
      requiresAuth: true,
      options: Options(responseType: ResponseType.plain),
    )).data!,
  );
  Future<List<BookingOffer>> offers() async =>
      (await _readMoney('$_base/booking-offers') as List)
          .map(BookingOffer.fromJson)
          .toList();
  Future<List<BookingEvent>> events(int after) async {
    if (after < 0) throw const FormatException('Invalid event cursor');
    return ((await client.get<Object?>(
              '$_base/booking-events',
              queryParameters: {'after': after},
              requiresAuth: true,
            )).data
            as List)
        .map(BookingEvent.fromJson)
        .toList();
  }

  Future<BookingDecision> decide(int offerId, {required bool accept}) async {
    try {
      return BookingDecision.fromJson(
        (await client.post<Object?>(
          '$_base/booking-offers/${bookingId(offerId)}/${accept ? 'accept' : 'decline'}',
          requiresAuth: true,
        )).data,
      );
    } on NetworkException catch (e) {
      if (e.statusCode == 409) {
        throw const FormatException(
          'This offer is no longer available. Another provider may have accepted it.',
        );
      }
      rethrow;
    }
  }

  Future<AssignedBooking> booking(int jobId) async => AssignedBooking.fromJson(
    await _readMoney('$_base/bookings/${bookingId(jobId)}'),
  );
  Future<BookingTransition> start(int jobId, String code) async {
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      throw const FormatException(
        'Enter the four-digit code from your customer.',
      );
    }
    return BookingTransition.fromJson(
      (await client.post<Object?>(
        '$_base/bookings/${bookingId(jobId)}/start',
        data: {'code': code},
        requiresAuth: true,
      )).data,
    );
  }

  Future<BookingTransition> complete(int jobId) async =>
      BookingTransition.fromJson(
        (await client.post<Object?>(
          '$_base/bookings/${bookingId(jobId)}/complete',
          requiresAuth: true,
        )).data,
      );
  Future<BookingPaymentWindow> paymentWindow(int requestId) async =>
      BookingPaymentWindow.fromJson(
        await _readMoney(
          '$_base/booking-requests/${bookingId(requestId)}/payment-window',
        ),
      );

  Future<void> cancelUnpaid(int requestId) async {
    await client.post<Object?>(
      '$_base/booking-requests/${bookingId(requestId)}/cancel',
      requiresAuth: true,
    );
  }

  Future<void> extendDeadline(int requestId, DateTime target) async {
    await client.put<Object?>(
      '$_base/booking-requests/${bookingId(requestId)}/payment-deadline',
      requiresAuth: true,
      data: {'confirmationExpiresAt': target.toUtc().toIso8601String()},
    );
  }

  Future<int> registerDevice({
    required String token,
    required String platform,
    required String deviceName,
  }) async {
    if (token.trim().isEmpty || !['ANDROID', 'IOS'].contains(platform)) {
      throw const FormatException('Invalid booking device');
    }
    return bookingId(
      bookingObject(
        (await client.post<Object?>(
          '/me/booking-devices',
          requiresAuth: true,
          data: {
            'token': token,
            'platform': platform,
            'deviceName': deviceName,
          },
        )).data,
      )['deviceId'],
    );
  }

  Future<void> unregisterDevice(int deviceId) async {
    await client.delete<Object?>(
      '/me/booking-devices/${bookingId(deviceId)}',
      requiresAuth: true,
    );
  }
}
