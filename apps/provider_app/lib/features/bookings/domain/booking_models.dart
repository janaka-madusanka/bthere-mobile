import '../../wallet/domain/wallet_models.dart' show WalletMoney;

Map<String, dynamic> bookingObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid booking response');
  }
  return value;
}

int bookingId(Object? value) {
  if (value is! int || value <= 0) {
    throw const FormatException('Invalid booking identifier');
  }
  return value;
}

/// Only the server's net earnings are exposed to presentation.
class BookingOffer {
  BookingOffer.fromJson(Object? value) {
    final j = bookingObject(value);
    id = bookingId(j['offerId']);
    requestId = bookingId(j['requestId']);
    serviceTypeId = bookingId(j['serviceTypeId']);
    optionId = bookingId(j['optionId']);
    status = j['status'] as String;
    final deadline = j['expiresAt'] as String;
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(deadline)) {
      throw const FormatException('Offer deadline must include a timezone');
    }
    expiresAt = DateTime.parse(deadline).toUtc();
    deliveryMode = j['deliveryMode'] as String;
    start =
        j['startDatetime'] as String? ?? j['requestedPickupTime'] as String?;
    end = j['expectedEndDatetime'] as String?;
    currency = j['currencyCode'] as String;
    earnings = WalletMoney.parse(j['providerEarnings']).formatted;
    final location = j['meetingPoint'] ?? j['pickup'];
    address = location is Map
        ? (location['address'] ?? location['name']) as String?
        : null;
    address ??= j['providerLocationId'] == null
        ? null
        : 'Your service location';
  }
  late final int id, requestId, serviceTypeId, optionId;
  late final String status, deliveryMode, currency, earnings;
  late final DateTime expiresAt;
  late final String? start, end;
  String? address;
  bool pendingAt(DateTime now) => status == 'PENDING' && expiresAt.isAfter(now);
  String get earningsLabel => "You'll earn $currency $earnings";
}

class BookingDecision {
  BookingDecision.fromJson(Object? value) {
    final j = bookingObject(value);
    requestId = bookingId(j['requestId']);
    jobId = j['jobId'] == null ? null : bookingId(j['jobId']);
    status = j['status'] as String;
  }
  late final int requestId;
  late final int? jobId;
  late final String status;
}

class AssignedBooking {
  AssignedBooking.fromJson(Object? value) {
    final j = bookingObject(value);
    id = bookingId(j['jobId']);
    serviceTypeId = bookingId(j['serviceTypeId']);
    status = j['status'] as String;
    paymentStatus = j['paymentStatus'] as String;
    currency = j['currencyCode'] as String;
    earnings = WalletMoney.parse(j['providerEarnings']).formatted;
    start = j['startDatetime'] as String?;
    end = j['expectedEndDatetime'] as String?;
    address = j['meetingPointName'] as String?;
    answers = j['answers'];
    // Preserve the authorized configuration and price snapshot for detail views.
    details = Map<String, dynamic>.unmodifiable({
      for (final key in const [
        'optionId',
        'providerId',
        'providerIds',
        'deliveryMode',
        'schedulingModel',
        'fulfillmentModel',
        'capacityUsed',
        'providerLocationId',
        'meetingPointName',
        'latitude',
        'longitude',
        'destinationLatitude',
        'destinationLongitude',
        'destinationAddress',
        'estimatedDistanceKm',
        'estimatedDurationMinutes',
        'rateId',
        'expectedAmount',
        'paymentMethod',
        'platformFeePercentage',
        'platformFee',
        'pricingSelections',
        'pricingSnapshot',
      ])
        if (j.containsKey(key)) key: j[key],
    });
  }
  late final int id, serviceTypeId;
  late final String status, paymentStatus, currency, earnings;
  late final String? start, end, address;
  late final Object? answers;
  late final Map<String, dynamic> details;
  Object? get pricingSelections => details['pricingSelections'];
  Object? get pricingSnapshot => details['pricingSnapshot'];
  bool get completed => status == 'COMPLETED';
  bool get paid => paymentStatus == 'PAID' || paymentStatus == 'SETTLED';
  bool get canStart => paid && status == 'BOOKING_CONFIRMED';
  bool get canComplete => paid && status == 'IN_PROGRESS';
  String get earningsLabel => "You'll earn $currency $earnings";
  String get statusLabel => switch (status) {
    'AWAITING_COMPLETION_CONFIRMATION' => 'Waiting for customer confirmation',
    'AWAITING_PAYMENT' => 'Waiting for customer payment',
    'AWAITING_CUSTOMER_CONFIRMATION' => 'Waiting for customer confirmation',
    'IN_PROGRESS' => 'In progress',
    'COMPLETED' => 'Completed',
    _ => status.replaceAll('_', ' ').toLowerCase(),
  };
}

class BookingEvent {
  BookingEvent.fromJson(Object? value) {
    final j = bookingObject(value);
    id = bookingId(j['eventId']);
    requestId = bookingId(j['requestId']);
    type = (j['eventType'] ?? j['type']) as String;
  }
  late final int id, requestId;
  late final String type;
}

class BookingTransition {
  BookingTransition.fromJson(Object? value) {
    final j = bookingObject(value);
    successful = j['successful'] == true;
    status = j['status'] as String;
  }
  late final bool successful;
  late final String status;
}
