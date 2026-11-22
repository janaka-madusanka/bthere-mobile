import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'registration_region.dart';

/// Native address lookup is separate from the Google Maps rendering SDK.
abstract interface class RegistrationGeocoder {
  Future<List<Map<String, dynamic>>> search(String query);
  Future<Map<String, dynamic>> reverse(double latitude, double longitude);
}

final registrationGeocoderProvider = Provider<RegistrationGeocoder>(
  (ref) => NativeRegistrationGeocoder(),
);

class NativeRegistrationGeocoder implements RegistrationGeocoder {
  Geocoding get _client => Geocoding();
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return [];
    final scopedQuery = normalized.toLowerCase().contains('sri lanka')
        ? normalized
        : '$normalized, Sri Lanka';
    final locations = await _client.locationFromAddress(scopedQuery);
    final seen = <String>{};
    final matches = await Future.wait(
      locations
          .where(
            (point) =>
                isSriLankaPoint(point.latitude, point.longitude) &&
                seen.add(
                  '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
                ),
          )
          .take(5)
          .map((point) async {
            Map<String, dynamic> address = {};
            try {
              address = await reverse(
                point.latitude,
                point.longitude,
              ).timeout(const Duration(seconds: 5));
            } on OutsideSriLanka {
              return <String, dynamic>{};
            } catch (_) {
              // A searchable point remains usable when its address cannot be resolved.
            }
            return <String, dynamic>{
              'locationName': query,
              ...address,
              'latitude': point.latitude,
              'longitude': point.longitude,
            };
          }),
    );
    return matches.where((match) => match.isNotEmpty).toList();
  }

  @override
  Future<Map<String, dynamic>> reverse(
    double latitude,
    double longitude,
  ) async {
    if (!isSriLankaPoint(latitude, longitude)) {
      throw const OutsideSriLanka();
    }
    final places = await _client.placemarkFromCoordinates(latitude, longitude);
    if (places.isEmpty) return {};
    final place = places.first;
    final countryCode = place.isoCountryCode?.trim().toUpperCase();
    if (countryCode != null && countryCode.isNotEmpty && countryCode != 'LK') {
      throw const OutsideSriLanka();
    }
    final name = [place.street, place.locality, place.administrativeArea]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .join(', ');
    return {
      if (name.isNotEmpty) 'locationName': name,
      'country': place.country,
      'province': place.administrativeArea,
      'district': place.subAdministrativeArea,
      'city': place.locality ?? place.subAdministrativeArea,
    };
  }
}
