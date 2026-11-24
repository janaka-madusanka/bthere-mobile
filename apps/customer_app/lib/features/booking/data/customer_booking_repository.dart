import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:bthere_network/bthere_network.dart';
import 'package:http_parser/http_parser.dart';

import '../../auth/data/customer_auth_service.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../../profile/data/customer_photo_upload.dart';
import '../domain/booking_models.dart';
import '../domain/booking_card_checkout.dart';
import '../domain/provider_reviews.dart';
import '../domain/booking_tracking.dart';
import '../domain/booking_cancellation.dart';

class CustomerBookingRepository {
  CustomerBookingRepository(this.auth, {this.onServerDate});
  final CustomerAuthService auth;
  final void Function(String?)? onServerDate;
  Future<BookingCancellation> cancellationPreview(int jobId) async =>
      BookingCancellation.parse(
        await request(
          'GET',
          '/customers/me/bookings/$jobId/cancellation-preview',
        ),
        jobId,
      );
  Future<BookingCancellation> cancelPaidBooking(
    int jobId,
    BookingCancellation preview,
    String reason,
    String note,
  ) async {
    if (reason.trim().isEmpty ||
        reason.trim().length > 100 ||
        note.length > 1000 ||
        preview.data['jobId'] != jobId) {
      throw const FormatException('Invalid cancellation input');
    }
    return BookingCancellation.parse(
      await request(
        'POST',
        '/customers/me/bookings/$jobId/cancel',
        data: {
          'reason': reason.trim(),
          'note': note.trim().isEmpty ? null : note.trim(),
          'expectedRefundAmount': preview.refund,
        },
      ),
      jobId,
      receipt: true,
    );
  }

  Future<BookingCancellation> cancellation(int jobId) async =>
      BookingCancellation.parse(
        await request('GET', '/customers/me/bookings/$jobId/cancellation'),
        jobId,
        receipt: true,
      );
  Future<int> registerBookingDevice(String token, String platform) async {
    final value = object(
      await request(
        'POST',
        '/me/booking-devices',
        data: {
          'token': token,
          'platform': platform,
          'deviceName': 'BThere Customer',
        },
      ),
    );
    return positiveId(value['deviceId']);
  }

  Future<void> removeBookingDevice(int id) async {
    final response = await auth.bookingRequest(
      'DELETE',
      '/me/booking-devices/$id',
    );
    if (![200, 204, 404].contains(response.statusCode)) {
      throw const FormatException('Device could not be removed');
    }
  }

  Future<BookingTrackingStatus> trackingStatus(int jobId) async =>
      BookingTrackingStatus.parse(
        await request('GET', '/customers/me/bookings/$jobId/tracking'),
        jobId,
      );
  Future<List<ProviderRatingSummary>> providerRatings(int providerId) async {
    final result = object(
      await request('GET', '/customers/me/providers/$providerId/ratings'),
    );
    if (result['providerId'] != providerId || result['options'] is! List) {
      throw const FormatException('Invalid provider ratings');
    }
    final summaries = [
      ProviderRatingSummary.parse(result['overall']),
      for (final value in result['options'] as List)
        ProviderRatingSummary.parse(value, option: true),
    ];
    if (summaries.map((s) => s.optionId).toSet().length != summaries.length) {
      throw const FormatException('Duplicate rating scope');
    }
    return summaries;
  }

  Future<ProviderReviewPage> providerReviews(
    int providerId, {
    int? optionId,
    int page = 0,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '10',
        if (optionId != null) 'optionId': '$optionId',
      },
    ).query;
    final result = object(
      await request(
        'GET',
        '/customers/me/providers/$providerId/reviews?$query',
      ),
    );
    if (result['content'] is! List ||
        result['number'] != page ||
        result['totalPages'] is! int ||
        (result['totalPages'] as int) < 0) {
      throw const FormatException('Invalid reviews page');
    }
    final rows = (result['content'] as List).map(ProviderReview.parse).toList();
    if (optionId != null && rows.any((r) => r.optionId != optionId)) {
      throw const FormatException('Review scope mismatch');
    }
    return ProviderReviewPage(rows, page, result['totalPages'] as int);
  }

  Future<List<Map<String, dynamic>>> bookingProviders(int jobId) async {
    final value = object(
      await request('GET', '/customers/me/bookings/$jobId/providers'),
    );
    if (value['jobId'] != jobId || value['providers'] is! List) {
      throw const FormatException('Invalid booking providers');
    }
    final ids = <int>{};
    return (value['providers'] as List).map((raw) {
      final provider = object(raw);
      if (provider['providerId'] is! int ||
          !ids.add(provider['providerId'] as int) ||
          provider['displayName'] is! String ||
          provider['contact'] is! Map) {
        throw const FormatException('Invalid booking provider');
      }
      return provider;
    }).toList();
  }

  Future<Map<String, dynamic>> bookingRatings(int jobId) async {
    final value = object(
      await request('GET', '/customers/me/bookings/$jobId/ratings'),
    );
    if (value['jobId'] != jobId ||
        value['canRate'] is! bool ||
        value['providers'] is! List) {
      throw const FormatException('Invalid booking ratings');
    }
    final ids = <int>{};
    for (final raw in value['providers'] as List) {
      final provider = object(raw);
      if (provider['providerId'] is! int ||
          !ids.add(provider['providerId'] as int) ||
          provider['rated'] is! bool ||
          provider['displayName'] != null &&
              provider['displayName'] is! String ||
          provider['rated'] == true &&
              (provider['rating'] is! Map ||
                  provider['rating']['rating'] is! int ||
                  (provider['rating']['rating'] as int) < 1 ||
                  (provider['rating']['rating'] as int) > 5)) {
        throw const FormatException('Invalid rating provider');
      }
    }
    return value;
  }

  Future<void> rateProvider(
    int jobId,
    int providerId,
    int rating,
    String comment,
  ) async {
    if (rating < 1 || rating > 5 || comment.length > 1000) {
      throw const FormatException('Invalid rating');
    }
    final value = object(
      await request(
        'POST',
        '/customers/me/bookings/$jobId/ratings',
        data: {
          'providerId': providerId,
          'rating': rating,
          if (comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      ),
    );
    if (value['jobId'] != jobId ||
        value['providerId'] != providerId ||
        value['rating'] != rating) {
      throw const FormatException('Rating result not confirmed');
    }
  }

  Future<void> confirmCompletion(int jobId) async {
    final result = object(
      await request('POST', '/customers/me/bookings/$jobId/confirm-completion'),
    );
    if (result['successful'] != true || result['status'] != 'COMPLETED') {
      throw const FormatException('Completion result is not confirmed');
    }
  }

  Future<Map<String, dynamic>> startCode(int jobId) async {
    final result = object(
      await request('GET', '/customers/me/bookings/$jobId/verification-codes'),
    );
    final code = result['code'];
    final expiry = DateTime.tryParse('${result['expiresAt']}');
    if (result['purpose'] != 'START' ||
        code is! String ||
        !RegExp(r'^\d{4}$').hasMatch(code) ||
        expiry == null ||
        !expiry.isUtc) {
      throw const FormatException('Invalid start code response');
    }
    return result;
  }

  Future<Map<String, dynamic>> changePaymentMethod(
    int id,
    String method,
  ) async {
    final view = requestView(
      await request(
        'POST',
        '/customers/me/booking-requests/$id/payment-method',
        data: {'paymentMethod': method},
      ),
    );
    if (view['requestId'] != id ||
        view['paymentMethod'] != null && view['paymentMethod'] != method) {
      throw const FormatException('Payment method change not confirmed');
    }
    return view;
  }

  Future<Map<String, dynamic>> paymentWindow(int id) async {
    final value = object(
      await request('GET', '/customers/me/booking-requests/$id/payment-window'),
    );
    if (value['requestId'] != id ||
        value['canPay'] is! bool ||
        value['canCancel'] is! bool ||
        value['confirmationExpiresAt'] != null &&
            DateTime.tryParse('${value['confirmationExpiresAt']}') == null ||
        value['paymentRetryStartedAt'] != null &&
            DateTime.tryParse('${value['paymentRetryStartedAt']}') == null) {
      throw const FormatException('Invalid payment window');
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> events(int after) async {
    final value = await request(
      'GET',
      '/customers/me/booking-events?after=$after',
    );
    if (value is! List) throw const FormatException('Invalid booking events');
    return value.map(object).toList();
  }

  Future<Map<String, dynamic>> confirmMockCard(int id, int methodId) async =>
      requestView(
        await request(
          'POST',
          '/customers/me/booking-requests/$id/confirm-mock-card',
          data: {'methodId': methodId},
        ),
      );
  Future<BookingCardCheckout> confirmRequestCard(
    int id,
    Map<String, String> billing,
  ) async => BookingCardCheckout.parse(
    await request(
      'POST',
      '/customers/me/booking-requests/$id/confirm',
      data: billing,
    ),
  );
  Future<Map<String, dynamic>> cancelRequest(int id) async {
    final view = requestView(
      await request('POST', '/customers/me/booking-requests/$id/cancel'),
    );
    if (view['requestId'] != id || view['status'] != 'CANCELLED') {
      throw const FormatException('Cancellation not confirmed');
    }
    return view;
  }

  Future<Map<String, dynamic>> confirmRequestWallet(int requestId) async {
    final view = requestView(
      await request(
        'POST',
        '/customers/me/booking-requests/$requestId/confirm-wallet',
      ),
    );
    if (view['requestId'] != requestId) {
      throw const FormatException('Invalid wallet confirmation identity');
    }
    return view;
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    int status = 200,
    Map<String, Object?>? headers,
    bool safeRead = false,
  }) async {
    final response = await auth.bookingRequest(
      method,
      path,
      data: data,
      headers: headers,
      safeRead: safeRead || method == 'GET',
    );
    onServerDate?.call(response.headers.value('date'));
    if (kDebugMode &&
        method == 'GET' &&
        RegExp(r'^/customers/me/bookings/\d+/(providers|ratings)$')
            .hasMatch(path)) {
      // Status only: no personal data, photos, tokens or response bodies.
      debugPrint(
        'Booking details read: path=$path http=${response.statusCode}',
      );
    }
    if (kDebugMode &&
        (RegExp(
              r'^/customers/me/booking-requests/\d+(/(payment-window|payment-method|confirm-mock-card|confirm-wallet|confirm))?$',
            ).hasMatch(path) ||
            path == '/me/payment-settings')) {
      final body = response.data;
      final state = body is Map ? body : const {};
      String label(String key) {
        final value = state[key];
        return value is String && RegExp(r'^[A-Z_]{1,48}$').hasMatch(value)
            ? value
            : '-';
      }

      // Debug-only lifecycle diagnostics. Never log bodies, auth, gateway
      // signatures, contact details, card identifiers or verification codes.
      debugPrint(
        'Booking payment: method=$method path=$path http=${response.statusCode} '
        'state=${label('status')} payment=${label('paymentStatus')} '
        'methodType=${label('paymentMethod')} gateway=${label('provider')}',
      );
    }
    if (response.statusCode != status) {
      final body = response.data;
      final map = body is Map ? body : const {};
      final detail = map['detail'] ?? map['message'] ?? map['title'];
      final errors = map['errors'];
      throw BookingProblem(
        detail is String && detail.trim().isNotEmpty
            ? detail
            : 'The request could not be completed. Please try again.',
        status: response.statusCode,
        errors: errors is Map
            ? {
                for (final e in errors.entries)
                  if (e.key is String && e.value is String)
                    e.key as String: e.value as String,
              }
            : {},
        eligibility: map['eligibility'] is Map,
      );
    }
    return response.data;
  }

  String query(BookingKey key) =>
      'serviceTypeId=${key.serviceId}&optionId=${key.optionId}';
  Future<Map<String, dynamic>> requestPolicy(int optionId) async {
    Map<String, dynamic> result;
    try {
      result = object(
        await request(
          'GET',
          '/customers/me/booking-requests/policy?optionId=$optionId',
        ),
      );
    } on BookingProblem catch (failure) {
      if (failure.status == 404) return {'enabled': false};
      rethrow;
    }
    if (result['enabled'] is! bool) {
      throw const FormatException('Invalid booking policy');
    }
    if (result['enabled'] == true &&
        (result['minimumNoticeMinutes'] is! int ||
            (result['minimumNoticeMinutes'] as int) < 0 ||
            result['maximumRadiusKm'] is! num ||
            !(result['maximumRadiusKm'] as num).isFinite ||
            (result['maximumRadiusKm'] as num) <= 0)) {
      throw const FormatException('Invalid request limits');
    }
    return result;
  }

  Map<String, dynamic> requestView(Object? value) {
    final row = object(value);
    positiveId(row['requestId']);
    text(row['status']);
    text(row['paymentStatus']);
    if (!{'OPEN_REQUEST', 'DIRECT_REQUEST'}.contains(row['selectionMode'])) {
      throw const FormatException('Invalid request selection');
    }
    if (row['expectedAmount'] != null &&
        (row['expectedAmount'] is! num ||
            !(row['expectedAmount'] as num).isFinite ||
            (row['expectedAmount'] as num) < 0)) {
      throw const FormatException('Invalid request amount');
    }
    if (row['jobId'] != null) positiveId(row['jobId']);
    return row;
  }

  Future<Map<String, dynamic>> createRequest(
    Map<String, Object?> input,
    String idempotencyKey,
  ) async => requestView(
    await request(
      'POST',
      '/customers/me/booking-requests',
      data: input,
      status: 201,
      headers: {'Idempotency-Key': idempotencyKey},
    ),
  );
  Future<Map<String, dynamic>> readRequest(int id) async =>
      requestView(await request('GET', '/customers/me/booking-requests/$id'));
  Future<BookingContext> context(
    BookingKey key, {
    GeoPoint? pricingPoint,
  }) async => BookingContext.parse(
    await request(
      'GET',
      '/customers/me/booking-context?marketId=${key.marketId}&${query(key)}${pricingPoint == null ? '' : '&pricingLatitude=${pricingPoint.latitude}&pricingLongitude=${pricingPoint.longitude}'}',
    ),
    key,
  );
  Future<List<CustomerRequirement>> requirements(BookingKey key) async {
    final raw = await request(
      'GET',
      '/customers/me/requirements?${query(key)}',
    );
    if (raw is! List) {
      throw const FormatException('Invalid requirements response');
    }
    final fields = raw.map(CustomerRequirement.parse).toList()
      ..sort((a, b) => a.field.order.compareTo(b.field.order));
    if (fields.map((f) => f.field.id).toSet().length != fields.length) {
      throw const FormatException('Duplicate requirements');
    }
    return fields;
  }

  Future<Map<String, dynamic>> eligibility(BookingKey key) async {
    final result = object(
      await request('GET', '/customers/me/eligibility?${query(key)}'),
    );
    if (result['eligible'] is! bool || result['reasons'] is! List) {
      throw const FormatException('Invalid eligibility');
    }
    return result;
  }

  Future<void> saveRequirements(List<Map<String, Object?>> submissions) async {
    if (submissions.length > 100) {
      throw const BookingProblem('Save at most 100 requirements at a time.');
    }
    final result = await request(
      'PUT',
      '/customers/me/requirement-submissions',
      data: {'submissions': submissions},
    );
    if (result is! List) {
      throw const FormatException('Invalid requirement save response');
    }
  }

  Future<Map<String, dynamic>> search(Map<String, Object?> input) async {
    final data = object(
      await request(
        'POST',
        '/customers/me/provider-search',
        data: input,
        safeRead: true,
      ),
    );
    if (!{'AVAILABLE', 'NO_AVAILABLE_PROVIDERS'}.contains(data['status']) ||
        data['candidates'] is! List ||
        data['hasNext'] is! bool ||
        data['totalCandidates'] is! int ||
        (data['totalCandidates'] as int) < 0 ||
        data['requiredProviderCount'] is! int ||
        data['page'] != input['page'] ||
        data['marketId'] != input['marketId']) {
      throw const FormatException('Invalid search response');
    }
    for (final row in data['candidates'] as List) {
      final candidate = ProviderCandidate.parse(row);
      if (candidate.data['optionId'] != input['optionId']) {
        throw const FormatException('Invalid candidate option');
      }
      if (input['deliveryMode'] == 'ONLINE' && candidate.point != null ||
          input['deliveryMode'] == 'CUSTOMER_TO_PROVIDER' &&
              candidate.locationId == null) {
        throw const FormatException('Invalid candidate location');
      }
    }
    if (data['status'] == 'NO_AVAILABLE_PROVIDERS' &&
        (data['candidates'] as List).isNotEmpty) {
      throw const FormatException('Inconsistent provider availability');
    }
    return data;
  }

  Future<Map<String, dynamic>> estimate(Map<String, Object?> input) async {
    final result = object(
      await request(
        'POST',
        '/customers/me/bookings/estimate',
        data: input,
        safeRead: true,
      ),
    );
    return _price(result);
  }

  Map<String, dynamic> _price(Map<String, dynamic> result) {
    final amount = result['expectedAmount'];
    if (amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        text(result['currencyCode']).trim().isEmpty) {
      throw const FormatException('Invalid quote total');
    }
    return result;
  }

  Future<Map<String, dynamic>> quote(Map<String, Object?> input) async {
    final result = object(
      await request(
        'POST',
        '/customers/me/bookings/quote',
        data: input,
        safeRead: true,
      ),
    );
    return _price(result);
  }

  Future<Map<String, dynamic>> book(Map<String, Object?> input) async {
    final raw = await request(
      'POST',
      '/customers/me/bookings',
      data: input,
      status: 201,
    );
    return booking(raw);
  }

  Map<String, dynamic> booking(Object? raw) {
    final row = object(raw);
    positiveId(row['jobId']);
    positiveId(row['serviceTypeId']);
    positiveId(row['optionId']);
    text(row['status']);
    text(row['paymentStatus']);
    text(row['paymentMethod']);
    text(row['currencyCode']);
    if (row['expectedAmount'] is! num ||
        !(row['expectedAmount'] as num).isFinite) {
      throw const FormatException('Invalid booking total');
    }
    return row;
  }

  Future<List<Map<String, dynamic>>> history() async {
    final raw = await request('GET', '/customers/me/bookings');
    if (raw is! List) throw const FormatException('Invalid booking history');
    return raw.map(booking).toList();
  }

  Future<Map<String, dynamic>> capabilities() async {
    final result = object(await request('GET', '/me/payment-settings'));
    return object(result['capabilities']);
  }

  Future<Map<String, dynamic>> pay(int jobId, String method) async {
    final path = method == 'WALLET' ? 'wallet-payment' : 'card-payment-session';
    final result = object(
      await request(
        'POST',
        '/customers/me/bookings/$jobId/$path',
        headers: method == 'CARD'
            ? {'Idempotency-Key': 'bthere-card-booking-$jobId'}
            : null,
      ),
    );
    text(result['status']);
    return result;
  }

  Future<String> upload(
    BookingField field,
    Uint8List bytes,
    String name,
  ) async {
    if (bytes.isEmpty ||
        bytes.length > 100 * 1024 * 1024 ||
        bytes.length > field.maxMb * 1024 * 1024) {
      throw BookingProblem(
        'Choose a file no larger than ${field.maxMb.clamp(1, 100)} MB.',
      );
    }
    final photo = customerPhotoMime(bytes);
    final pdf =
        bytes.length >= 5 &&
        String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
    final kind = pdf
        ? 'PDF'
        : switch (photo) {
            'image/jpeg' => 'JPG',
            'image/png' => 'PNG',
            'image/webp' => 'WEBP',
            _ => null,
          };
    if (kind == null ||
        field.type == 'IMAGE_UPLOAD' && pdf ||
        field.fileTypes.isNotEmpty && !field.fileTypes.contains(kind)) {
      throw const BookingProblem(
        'This file format is not supported by this field.',
      );
    }
    final raw = object(
      await request(
        'POST',
        '/uploads/documents',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: name,
            contentType: MediaType.parse(pdf ? 'application/pdf' : photo!),
          ),
        }),
      ),
    );
    return text(raw['key']);
  }

  Future<String> view(String key) async {
    final raw = object(
      await request('GET', '/uploads/view-url?key=${Uri.encodeComponent(key)}'),
    );
    final url = safeImageUrl(raw['url']);
    final expires = raw['expiresAt'];
    if (url == null ||
        raw['key'] != key ||
        expires is! String ||
        !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(expires) ||
        DateTime.tryParse(expires) == null) {
      throw const FormatException('Invalid private view URL');
    }
    return url;
  }

  Future<Map<String, dynamic>> mockCardEvent(
    int intentId,
    String outcome,
  ) async {
    if (!{'SUCCESS', 'FAILURE', 'REFUND'}.contains(outcome)) {
      throw ArgumentError('Invalid test outcome');
    }
    final result = object(
      await request(
        'POST',
        '/me/mock-payments/$intentId/events',
        data: {'outcome': outcome},
      ),
    );
    if (result['intentId'] != intentId) {
      throw const FormatException('Invalid test payment response');
    }
    text(result['status']);
    return result;
  }
}
