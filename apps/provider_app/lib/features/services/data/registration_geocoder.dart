import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

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
    final locations = await _client.locationFromAddress(query);
    return Future.wait(
      locations.take(5).map((point) async {
        Map<String, dynamic> address = {};
        try {
          address = await reverse(
            point.latitude,
            point.longitude,
          ).timeout(const Duration(seconds: 5));
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
  }

  @override
  Future<Map<String, dynamic>> reverse(
    double latitude,
    double longitude,
  ) async {
    final places = await _client.placemarkFromCoordinates(latitude, longitude);
    if (places.isEmpty) return {};
    final place = places.first;
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
