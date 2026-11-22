import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../booking/application/customer_booking_controller.dart';
import '../../booking/data/customer_booking_repository.dart';
import '../../discovery/domain/customer_discovery.dart' show object;

final customerProfileOverviewRepositoryProvider = Provider(
  (ref) => CustomerProfileOverviewRepository(
    ref.watch(customerBookingRepositoryProvider),
  ),
  dependencies: [customerBookingRepositoryProvider],
);
final customerProfileOverviewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>(
      (ref, owner) async {
        final auth = ref.watch(customerAuthControllerProvider);
        if (auth.user?.id != owner ||
            auth.stage != CustomerAuthStage.authenticated) {
          throw StateError('Signed out');
        }
        final result = await ref
            .watch(customerProfileOverviewRepositoryProvider)
            .overview();
        if (auth.user?.id != owner ||
            auth.stage != CustomerAuthStage.authenticated) {
          throw StateError('Session changed');
        }
        return result;
      },
      dependencies: [
        customerAuthControllerProvider,
        customerProfileOverviewRepositoryProvider,
      ],
    );

class ContactProblem implements Exception {
  const ContactProblem(this.message, {this.retrySeconds = 0});
  final String message;
  final int retrySeconds;
}

class CustomerProfileOverviewRepository {
  CustomerProfileOverviewRepository(this.booking);
  final CustomerBookingRepository booking;
  Future<Map<String, dynamic>> overview() async {
    final value = object(
      await booking.request(
        'GET',
        '/customers/me/profile-overview?recentLimit=5',
      ),
    );
    final contacts = object(value['contacts']);
    for (final flag in ['emailVerified', 'phoneVerified']) {
      if (contacts[flag] is! bool) {
        throw const FormatException('Invalid verification status');
      }
    }
    for (final key in ['email', 'phoneNumber']) {
      if (contacts[key] != null && contacts[key] is! String) {
        throw const FormatException('Invalid contact');
      }
    }
    final stats = object(value['statistics']);
    for (final key in [
      'pendingCount',
      'activeCount',
      'awaitingProviderCount',
      'completedCount',
      'cancelledCount',
      'excludedPaymentCount',
    ]) {
      if (stats[key] is! int || (stats[key] as int) < 0) {
        throw const FormatException('Invalid profile statistics');
      }
    }
    for (final key in ['spending', 'testSpending']) {
      if (stats[key] is! List) throw const FormatException('Invalid spending');
      for (final raw in stats[key]) {
        final row = object(raw);
        if (row['currencyCode'] is! String ||
            row['totalSpent'] is! num ||
            !(row['totalSpent'] as num).isFinite) {
          throw const FormatException('Invalid spending amount');
        }
      }
    }
    if (value['profile'] != null) object(value['profile']);
    if (value['documents'] is! List) {
      throw const FormatException('Invalid documents');
    }
    for (final key in ['pendingServices', 'serviceHistory']) {
      final list = object(value[key]);
      if (list['items'] is! List ||
          list['hasMore'] is! bool ||
          list['totalCount'] is! int) {
        throw const FormatException('Invalid service list');
      }
    }
    return value;
  }

  Future<Map<String, dynamic>> requests(
    int page, [
    String statuses = '',
  ]) async {
    if (page < 0) throw ArgumentError('Invalid page');
    final value = object(
      await booking.request(
        'GET',
        '/customers/me/booking-requests?page=$page&size=20${statuses.isEmpty ? '' : '&status=${Uri.encodeComponent(statuses)}'}',
      ),
    );
    if (value['page'] != page ||
        value['items'] is! List ||
        value['hasMore'] is! bool) {
      throw const FormatException('Invalid request list');
    }
    return value;
  }

  Future<Map<String, dynamic>> contact(
    String kind,
    String value, {
    String? otp,
    String? password,
  }) async {
    if (!{'email', 'phone'}.contains(kind)) {
      throw ArgumentError('Invalid contact type');
    }
    final destination = value.trim();
    if (kind == 'email'
        ? !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(destination)
        : !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(destination)) {
      throw ContactProblem(
        kind == 'email'
            ? 'Enter a valid email address.'
            : 'Use international format, e.g. +94771234567.',
      );
    }
    if (otp != null && !RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const ContactProblem('Enter the six-digit code.');
    }
    final response = await booking.auth.bookingRequest(
      'POST',
      '/customers/me/contacts/$kind/${otp == null ? 'otp' : 'verify'}',
      data: {
        kind == 'email' ? 'email' : 'phoneNumber': destination,
        'otp': ?otp,
        if (otp != null && password?.isNotEmpty == true)
          'currentPassword': password,
      },
    );
    if ((response.statusCode ?? 500) >= 500) {
      throw StateError('Contact result unknown');
    }
    if (response.statusCode != 200) {
      final body = response.data is Map ? response.data as Map : const {};
      const allowed = {
        'This email is already verified',
        'This phone number is already verified',
        'Verification code is invalid or expired',
        'Current password is required',
        'Current password is incorrect',
        'Email is already registered',
        'Phone number is already registered',
        'Email must be valid',
        'Phone number must use international E.164 format',
        'OTP must contain six digits',
        'Please wait before requesting another verification code',
      };
      final detail = body['detail'];
      final retry = body['retryAfterSeconds'];
      final header = int.tryParse(response.headers.value('retry-after') ?? '');
      throw ContactProblem(
        allowed.contains(detail) ? detail as String : 'Unable to update contact details. Check your profile before trying again.',
        retrySeconds: retry is int && retry > 0
            ? retry
            : header ?? (response.statusCode == 429 ? 60 : 0),
      );
    }
    final result = object(response.data);
    if (otp == null &&
        (result['destination'] is! String ||
            result['expiresIn'] is! int ||
            (result['expiresIn'] as int) <= 0 ||
            result['resendAfterSeconds'] is! int ||
            (result['resendAfterSeconds'] as int) < 0 ||
            result['destination'] !=
                (kind == 'email' ? destination.toLowerCase() : destination))) {
      throw const FormatException('Invalid OTP response');
    }
    if (otp != null &&
        (result[kind == 'email' ? 'emailVerified' : 'phoneVerified'] != true ||
            result[kind == 'email' ? 'email' : 'phoneNumber'] !=
                (kind == 'email' ? destination.toLowerCase() : destination))) {
      throw const FormatException('Contact update not confirmed');
    }
    return result;
  }
}
