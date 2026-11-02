import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:http_parser/http_parser.dart';

import '../../auth/data/customer_auth_service.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../../profile/data/customer_photo_upload.dart';
import '../domain/booking_models.dart';

class CustomerBookingRepository {
  CustomerBookingRepository(this.auth);
  final CustomerAuthService auth;
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
    if (url == null) throw const FormatException('Invalid private view URL');
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
