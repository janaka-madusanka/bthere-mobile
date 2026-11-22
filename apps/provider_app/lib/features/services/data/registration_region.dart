import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Camera/search envelope, including Sri Lanka's offshore islands.
final sriLankaBounds = LatLngBounds(
  southwest: const LatLng(5.8, 79.5),
  northeast: const LatLng(9.9, 82.0),
);
const sriLankaCenter = LatLng(7.85, 80.75);

bool isSriLankaPoint(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    sriLankaBounds.contains(LatLng(latitude, longitude));

class OutsideSriLanka implements Exception {
  const OutsideSriLanka();
}
