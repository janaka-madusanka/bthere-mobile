import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../domain/booking_models.dart';

/// Native reverse lookup for GPS/manual pins, independent of Places search.
final customerLocationAddressProvider =
    Provider<Future<String?> Function(GeoPoint)>(
      (ref) => (point) async {
        final places = await Geocoding()
            .placemarkFromCoordinates(point.latitude, point.longitude)
            .timeout(const Duration(seconds: 10));
        if (places.isEmpty) return null;
        final place = places.first;
        final parts =
            [
                  place.street,
                  place.subLocality,
                  place.locality,
                  place.subAdministrativeArea,
                  place.administrativeArea,
                  place.country,
                ]
                .whereType<String>()
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toSet();
        final address = parts.join(', ');
        return address.isEmpty ? null : address;
      },
    );
