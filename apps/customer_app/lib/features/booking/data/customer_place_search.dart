import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/booking_models.dart';

class PlaceResult {
  const PlaceResult(
    this.title,
    this.address,
    this.point, {
    this.placeId,
    this.attributions = const [],
  });
  final String title, address;
  // Autocomplete predictions have no coordinates until the customer selects one.
  final GeoPoint? point;
  final String? placeId;
  final List<String> attributions;
}

abstract class PlaceSearch {
  Future<List<PlaceResult>> search(String query, {String? countryCode});
  Future<PlaceResult> resolve(PlaceResult result) async => result;
}

final customerPlaceSearchProvider = Provider<PlaceSearch>(
  (ref) => GooglePlaceSearch(),
);

/// Uses native Android/iOS SDKs so mobile application key restrictions apply.
/// Predictions/details are transient and are never cached to disk or logged.
class GooglePlaceSearch extends PlaceSearch {
  GooglePlaceSearch({
    this.apiKey = const String.fromEnvironment('BTHERE_GOOGLE_MAPS_API_KEY'),
    places.FlutterGooglePlacesSdkPlatform? platform,
    this.timeout = const Duration(seconds: 15),
  }) : platform = platform ?? places.FlutterGooglePlacesSdk.platform;

  final String apiKey;
  final places.FlutterGooglePlacesSdkPlatform platform;
  final Duration timeout;
  Future<void>? _initialized;
  Future<void> _queue = Future.value();

  Future<void> _initialize() async {
    if (apiKey.trim().isEmpty) {
      throw const BookingProblem(
        'Location search is not configured. Choose a pin on the map instead.',
      );
    }
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const BookingProblem(
        'Location search is available in the Android and iOS apps.',
      );
    }
    try {
      await (_initialized ??= platform.initialize(
        apiKey,
        locale: const Locale('en'),
        useNewApi: true,
      )).timeout(timeout);
    } catch (_) {
      _initialized = null;
      rethrow;
    }
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final completion = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await _initialize();
        completion.complete(await action().timeout(timeout));
      } catch (error) {
        completion.completeError(
          error is BookingProblem
              ? error
              : const BookingProblem(
                  'Google location search is unavailable. Try again or choose a pin on the map.',
                ),
        );
      }
    });
    return completion.future;
  }

  @override
  Future<List<PlaceResult>> search(String query, {String? countryCode}) {
    final term = query.trim();
    if (term.length < 2 || term.length > 200) {
      return Future.error(
        const BookingProblem(
          'Enter a city, area or place name (2-200 characters).',
        ),
      );
    }
    final country =
        countryCode != null && RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)
        ? countryCode.toUpperCase()
        : null;
    return _run(() async {
      final response = await platform.findAutocompletePredictions(
        term,
        countries: country == null ? null : [country],
        newSessionToken: true,
      );
      final known = <String>{};
      return List.unmodifiable(
        [
          for (final prediction in response.predictions)
            if (prediction.placeId.isNotEmpty &&
                prediction.primaryText.trim().isNotEmpty &&
                known.add(prediction.placeId))
              PlaceResult(
                prediction.primaryText,
                prediction.fullText,
                null,
                placeId: prediction.placeId,
              ),
        ].take(5),
      );
    });
  }

  @override
  Future<PlaceResult> resolve(PlaceResult result) {
    if (result.point?.valid == true) return Future.value(result);
    final id = result.placeId;
    if (id == null || id.isEmpty) {
      return Future.error(
        const BookingProblem('Select a location from the search results.'),
      );
    }
    return _run(() async {
      final response = await platform.fetchPlace(
        id,
        fields: const [
          places.PlaceField.Id,
          places.PlaceField.Address,
          places.PlaceField.Location,
        ],
        newSessionToken: false,
      );
      final place = response.place;
      final location = place?.latLng;
      if (location == null) throw const FormatException('Missing coordinates');
      final point = GeoPoint(location.lat, location.lng);
      if (!point.valid || place?.id != id) {
        throw const FormatException('Invalid place');
      }
      return PlaceResult(
        result.title,
        place?.address ?? result.address,
        point,
        placeId: id,
        attributions: List.unmodifiable(
          place?.attributions ?? const <String>[],
        ),
      );
    });
  }
}
