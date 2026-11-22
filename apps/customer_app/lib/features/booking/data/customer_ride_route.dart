import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/booking_models.dart';

typedef RideEndpoints = (double, double, double, double);

/// Display geometry only. Fare and booking distance remain server-owned.
final customerRideRouteProvider = FutureProvider.autoDispose
    .family<List<GeoPoint>, RideEndpoints>((ref, points) async {
      const routeKey = String.fromEnvironment('BTHERE_GOOGLE_ROUTES_API_KEY');
      const mapKey = String.fromEnvironment('BTHERE_GOOGLE_MAPS_API_KEY');
      final key = routeKey.isEmpty ? mapKey : routeKey;
      if (key.isEmpty) throw const FormatException('Route preview unavailable');
      final client = http.Client();
      ref.onDispose(client.close);
      Map<String, Object> location(double lat, double lng) => {
        'location': {
          'latLng': {'latitude': lat, 'longitude': lng},
        },
      };
      final response = await client
          .post(
            Uri.https('routes.googleapis.com', '/directions/v2:computeRoutes'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
            },
            body: jsonEncode({
              'origin': location(points.$1, points.$2),
              'destination': location(points.$3, points.$4),
              'travelMode': 'DRIVE',
              'computeAlternativeRoutes': false,
              'polylineQuality': 'OVERVIEW',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('Route preview unavailable');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw const FormatException('No driving route');
      }
      return decodeRidePolyline(
        routes.first['polyline']['encodedPolyline'] as String,
      );
    });

List<GeoPoint> decodeRidePolyline(String encoded) {
  var index = 0, latitude = 0, longitude = 0;
  int delta() {
    var result = 0, shift = 0, byte = 0;
    do {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('Invalid route');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0 || byte > 63) throw const FormatException('Invalid route');
      result |= (byte & 31) << shift;
      shift += 5;
    } while (byte >= 32);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  final result = <GeoPoint>[];
  while (index < encoded.length) {
    latitude += delta();
    longitude += delta();
    final point = GeoPoint(latitude / 1e5, longitude / 1e5);
    if (!point.valid) throw const FormatException('Invalid route');
    result.add(point);
  }
  if (result.length < 2) throw const FormatException('No driving route');
  return result;
}
