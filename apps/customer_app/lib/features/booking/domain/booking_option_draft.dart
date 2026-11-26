import 'booking_models.dart';

/// Transfers common selections when changing options within the booking form.
class BookingOptionDraft {
  const BookingOptionDraft({
    required this.marketId,
    required this.userId,
    required this.start,
    required this.end,
    required this.address,
    required this.destinationAddress,
    required this.point,
    required this.destination,
    required this.radius,
    required this.mode,
    required this.languages,
    required this.skills,
    required this.filters,
    required this.serviceDetails,
    this.bookNow = false,
    this.answersById = const {},
    this.paymentMethod,
    this.customerNote = '',
  });
  final int marketId;
  final int? userId;
  final String start, end, address, destinationAddress;
  final GeoPoint? point, destination;
  final double radius;
  final String? mode;
  final Set<String> languages;
  final Set<int> skills;
  final Map<int, Object?> filters;
  final bool serviceDetails;
  final bool bookNow;
  final Map<int, Object?> answersById;
  final String? paymentMethod;
  final String customerNote;
}

/// Rebuild only editable selections, never the old request/provider assignment.
BookingOptionDraft recoveredBookingDraft(
  Map<String, dynamic> input,
  int marketId,
  int userId,
) {
  final booking = input['booking'] is Map
      ? Map<String, dynamic>.from(input['booking'] as Map)
      : input;
  GeoPoint? point(Object? raw) {
    if (raw is! Map) return null;
    try {
      return GeoPoint.parse(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  String address(Object? raw) {
    if (raw is! Map) return '';
    return '${raw['addressLine1'] ?? raw['address'] ?? raw['name'] ?? ''}';
  }

  final pickup =
      booking['meetingPoint'] ??
      booking['pickup'] ??
      input['searchLocation'] ??
      booking;
  return BookingOptionDraft(
    marketId: marketId,
    userId: userId,
    start:
        '${booking['startDatetime'] ?? booking['requestedPickupTime'] ?? ''}',
    end: '${booking['expectedEndDatetime'] ?? ''}',
    address: address(pickup),
    destinationAddress: address(booking['destination']),
    point: point(pickup),
    destination: point(booking['destination']),
    radius: (input['radiusKm'] as num?)?.toDouble() ?? 10,
    mode: booking['deliveryMode'] as String?,
    languages: (input['languages'] as List? ?? []).whereType<String>().toSet(),
    skills: (input['requiredSkillIds'] as List? ?? []).whereType<int>().toSet(),
    filters: {
      for (final row
          in input['providerFilters'] is List
              ? input['providerFilters'] as List
              : const [])
        if (row is Map && row['fieldId'] is int)
          row['fieldId']
              as int: row.containsKey('minimum') || row.containsKey('maximum')
              ? {
                  if (row.containsKey('minimum')) 'minimum': row['minimum'],
                  if (row.containsKey('maximum')) 'maximum': row['maximum'],
                }
              : row['value'],
    },
    serviceDetails: true,
    answersById: {
      for (final row
          in booking['answers'] is List ? booking['answers'] as List : const [])
        if (row is Map && row['fieldId'] is int)
          row['fieldId'] as int: row['value'],
    },
    paymentMethod: booking['paymentMethod'] as String?,
    customerNote: booking['customerNote'] as String? ?? '',
  );
}
