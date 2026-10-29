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
}
