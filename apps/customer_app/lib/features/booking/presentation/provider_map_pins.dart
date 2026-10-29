import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/booking_models.dart';

class ProviderMapPin {
  const ProviderMapPin(this.candidate, this.location, this.displayLocation);
  final ProviderCandidate candidate;
  final LatLng location, displayLocation;
  bool get separated => location != displayLocation;
}

/// Spiderfies coincident pins for readability; the connector retains the real
/// backend coordinate. Never change provider data or booking coordinates.
List<ProviderMapPin> providerMapPins(
  List<ProviderCandidate> candidates, {
  GeoPoint? searchPoint,
  double radiusKm = 5,
}) {
  final groups = <String, List<ProviderCandidate>>{};
  for (final candidate in candidates) {
    final point = candidate.point;
    if (point == null) {
      continue; // ONLINE/missing public coordinates are not invented.
    }
    final lat = (point['latitude'] as num).toDouble();
    final lng = (point['longitude'] as num).toDouble();
    groups
        .putIfAbsent(
          '${lat.toStringAsFixed(6)}/${lng.toStringAsFixed(6)}',
          () => [],
        )
        .add(candidate);
  }
  final pins = <ProviderMapPin>[];
  for (final group in groups.values) {
    group.sort((a, b) => a.key.compareTo(b.key));
    final point = GeoPoint.parse(group.first.point!);
    final overlapsSearch =
        searchPoint != null &&
        (point.latitude - searchPoint.latitude).abs() < .000001 &&
        (point.longitude - searchPoint.longitude).abs() < .000001;
    for (var index = 0; index < group.length; index++) {
      final candidate = group[index];
      final original = GeoPoint.parse(candidate.point!);
      final source = LatLng(original.latitude, original.longitude);
      if (group.length == 1 && !overlapsSearch) {
        pins.add(ProviderMapPin(candidate, source, source));
        continue;
      }
      final ring = index ~/ 6 + 1;
      final inRing = math.min(6, group.length - (ring - 1) * 6);
      final angle = 2 * math.pi * (index % 6) / inRing + (ring - 1) * .35;
      final distance = math.min(
        radiusKm * 1000 * .18 * ring,
        radiusKm * 1000 * .55,
      );
      final cosLatitude = math
          .cos(original.latitude * math.pi / 180)
          .abs()
          .clamp(.01, 1);
      var lat = original.latitude + distance * math.sin(angle) / 111320;
      var lng =
          original.longitude +
          distance * math.cos(angle) / (111320 * cosLatitude);
      // If the shared location is inside the selected circle, keep its visual
      // expansion inside too. Outlying coverage centres remain authoritative.
      if (searchPoint != null) {
        final scale = math
            .cos(searchPoint.latitude * math.pi / 180)
            .abs()
            .clamp(.01, 1);
        final originalX =
            (original.longitude - searchPoint.longitude) * 111320 * scale;
        final originalY = (original.latitude - searchPoint.latitude) * 111320;
        var x = (lng - searchPoint.longitude) * 111320 * scale;
        var y = (lat - searchPoint.latitude) * 111320;
        final radius = radiusKm * 1000;
        final length = math.sqrt(x * x + y * y);
        if (originalX * originalX + originalY * originalY <= radius * radius &&
            length > radius * .98) {
          x *= radius * .98 / length;
          y *= radius * .98 / length;
          lat = searchPoint.latitude + y / 111320;
          lng = searchPoint.longitude + x / (111320 * scale);
        }
      }
      pins.add(
        ProviderMapPin(
          candidate,
          source,
          LatLng(lat.clamp(-90, 90), lng.clamp(-180, 180)),
        ),
      );
    }
  }
  return pins;
}
