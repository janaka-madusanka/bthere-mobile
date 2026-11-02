import 'dart:async';

import 'package:customer_app/features/booking/data/customer_place_search.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as sdk;
import 'package:flutter_test/flutter_test.dart';

class FakePlaces extends sdk.FlutterGooglePlacesSdkPlatform {
  int initialized = 0, predictions = 0, details = 0;
  List<String>? countries;
  List<sdk.PlaceField>? fields;
  bool? newSession, detailSession, newApi;
  Object? error;
  Future<sdk.FindAutocompletePredictionsResponse> Function()? handler;
  sdk.Place? place = sdk.Place.fromJson({
    'id': 'kurunegala',
    'address': 'Kurunegala, Sri Lanka',
    'latLng': {'lat': 7.4870464, 'lng': 80.364908},
    'attributions': ['Example data credit'],
  });
  @override
  Future<void> initialize(
    String apiKey, {
    Locale? locale,
    bool? useNewApi,
  }) async {
    initialized++;
    newApi = useNewApi;
    expect(apiKey, 'synthetic-key');
  }

  @override
  Future<sdk.FindAutocompletePredictionsResponse> findAutocompletePredictions(
    String query, {
    List<String>? countries,
    List<String> placeTypesFilter = const [],
    bool? newSessionToken,
    sdk.LatLng? origin,
    sdk.LatLngBounds? locationBias,
    sdk.LatLngBounds? locationRestriction,
  }) async {
    predictions++;
    this.countries = countries;
    newSession = newSessionToken;
    expect(query, 'Kurunegala');
    if (error != null) throw error!;
    return handler?.call() ??
        const sdk.FindAutocompletePredictionsResponse([
          sdk.AutocompletePrediction(
            distanceMeters: null,
            placeId: 'kurunegala',
            primaryText: 'Kurunegala',
            secondaryText: 'Sri Lanka',
            fullText: 'Kurunegala, Sri Lanka',
          ),
        ]);
  }

  @override
  Future<sdk.FetchPlaceResponse> fetchPlace(
    String id, {
    required List<sdk.PlaceField> fields,
    bool? newSessionToken,
    String? regionCode,
  }) async {
    details++;
    this.fields = fields;
    detailSession = newSessionToken;
    expect(id, 'kurunegala');
    return sdk.FetchPlaceResponse(place);
  }
}

void main() {
  test('native predictions restrict country; only selected place fetches coordinates', () async {
    final native = FakePlaces();
    final service = GooglePlaceSearch(
      apiKey: 'synthetic-key',
      platform: native,
    );
    final results = await service.search(' Kurunegala ', countryCode: 'lk');
    expect(native.initialized, 1);
    expect(native.newApi, isTrue);
    expect(native.countries, ['LK']);
    expect(native.newSession, isTrue);
    expect(native.details, 0);
    expect(results.single.point, isNull);
    final resolved = await service.resolve(results.single);
    expect(resolved.point!.latitude, 7.4870464);
    expect(resolved.point!.longitude, 80.364908);
    expect(resolved.address, 'Kurunegala, Sri Lanka');
    expect(resolved.attributions, ['Example data credit']);
    expect(native.fields, [
      sdk.PlaceField.Id,
      sdk.PlaceField.Address,
      sdk.PlaceField.Location,
    ]);
    expect(native.detailSession, isFalse);
    expect(native.initialized, 1);
  });
  test('invalid query and missing key make no native requests', () async {
    final native = FakePlaces();
    final service = GooglePlaceSearch(apiKey: '', platform: native);
    await expectLater(service.search('a'), throwsA(isA<BookingProblem>()));
    await expectLater(
      service.search('Kurunegala'),
      throwsA(isA<BookingProblem>()),
    );
    expect(native.initialized, 0);
    expect(native.predictions, 0);
  });
  test(
    'missing or invalid coordinates cannot turn into a selected pin',
    () async {
      final native = FakePlaces();
      final service = GooglePlaceSearch(
        apiKey: 'synthetic-key',
        platform: native,
      );
      native.place = sdk.Place.fromJson({
        'id': 'kurunegala',
        'latLng': {'lat': 99.0, 'lng': 200.0},
      });
      await expectLater(
        service.resolve(
          const PlaceResult('Kurunegala', '', null, placeId: 'kurunegala'),
        ),
        throwsA(isA<BookingProblem>()),
      );
      native.place = null;
      await expectLater(
        service.resolve(
          const PlaceResult('Kurunegala', '', null, placeId: 'kurunegala'),
        ),
        throwsA(isA<BookingProblem>()),
      );
    },
  );
  test(
    'Google errors remain retryable and do not expose native error bodies',
    () async {
      final native = FakePlaces()
        ..error = PlatformException(
          code: 'REQUEST_DENIED',
          message: 'private native details',
        );
      final service = GooglePlaceSearch(
        apiKey: 'synthetic-key',
        platform: native,
      );
      await expectLater(
        service.search('Kurunegala'),
        throwsA(
          isA<BookingProblem>().having(
            (e) => e.message,
            'safe error',
            isNot(contains('private')),
          ),
        ),
      );
      native.error = null;
      expect(await service.search('Kurunegala'), hasLength(1));
      expect(native.predictions, 2);
    },
  );
  test('search calls serialize native session creation and do not cache Google content', () async {
    final native = FakePlaces();
    final pending = Completer<sdk.FindAutocompletePredictionsResponse>();
    native.handler = () => pending.future;
    final service = GooglePlaceSearch(
      apiKey: 'synthetic-key',
      platform: native,
    );
    final first = service.search('Kurunegala');
    final second = service.search('Kurunegala');
    await Future<void>.delayed(Duration.zero);
    expect(native.predictions, 1);
    pending.complete(const sdk.FindAutocompletePredictionsResponse([]));
    await Future.wait([first, second]);
    expect(native.predictions, 2);
  });
}
