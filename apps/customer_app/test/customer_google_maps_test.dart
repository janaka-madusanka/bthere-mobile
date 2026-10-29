import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/features/booking/presentation/customer_map_marker_icons.dart';
import 'package:customer_app/features/booking/presentation/provider_map_pins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'booking_fixture.dart';
import 'customer_test_map.dart';

void main() {
  testWidgets(
    'results photo pins are a fallback while admin-resolved marker icons keep priority',
    (tester) async {
      final custom = ProviderCandidate.parse({
        ...candidateJson(),
        'profilePhoto': 'https://example.invalid/first.png',
        'mapMarker': {
          'icon': {'url': 'https://example.invalid/custom.svg'},
        },
      });
      final photo = ProviderCandidate.parse({
        ...candidateJson(id: 16),
        'profilePhoto': 'https://example.invalid/second.png',
      });
      final customRequests = <String>[], photoRequests = <String>[];
      final customIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
      final photoIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
            customerMarkerIconLoaderProvider.overrideWithValue((url) async {
              customRequests.add(url);
              return customIcon;
            }),
            customerProviderPhotoMarkerLoaderProvider.overrideWithValue((
              url,
            ) async {
              photoRequests.add(url);
              return photoIcon;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingLocationPicker(
                point: const GeoPoint(6.92, 79.85),
                candidates: [custom, photo],
                preferProviderPhotos: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state;
      expect(customRequests, ['https://example.invalid/custom.svg']);
      expect(photoRequests, ['https://example.invalid/second.png']);
      final customPin = state.markers.singleWhere(
        (m) => m.markerId.value == 'provider-${custom.key}',
      );
      final photoPin = state.markers.singleWhere(
        (m) => m.markerId.value == 'provider-${photo.key}',
      );
      expect(customPin.icon, customIcon);
      expect(photoPin.icon, photoIcon);
      expect(photoPin.anchor, const Offset(.5, .5));
    },
  );
  testWidgets(
    'unselected map opens on Sri Lanka without choosing a booking point',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingLocationPicker(
                point: null,
                onChanged: (_) => fail('Default camera selected a location'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state;
      expect(state.camera.target, const LatLng(7.8731, 80.7718));
      expect(state.camera.zoom, 6.5);
      expect(state.markers, isEmpty);
    },
  );

  test('overlapping provider pins are separated without changing backend coordinates', () {
    final candidates = [
      for (var id = 15; id < 35; id++)
        ProviderCandidate.parse(candidateJson(id: id)),
    ];
    final pins = providerMapPins(
      candidates,
      searchPoint: const GeoPoint(6.93, 79.86),
    );
    expect(pins, hasLength(20));
    expect(pins.map((pin) => pin.displayLocation).toSet(), hasLength(20));
    for (final pin in pins) {
      expect(pin.location, const LatLng(6.93, 79.86));
      expect(pin.separated, isTrue);
      expect(pin.candidate.point, {'latitude': 6.93, 'longitude': 79.86});
    }
    final reversed = providerMapPins(
      candidates.reversed.toList(),
      searchPoint: const GeoPoint(6.93, 79.86),
    );
    expect(
      reversed.map((p) => p.displayLocation),
      pins.map((p) => p.displayLocation),
    );
  });

  test('different provider locations remain exact and missing coordinates are not fabricated', () {
    final candidates = [
      ProviderCandidate.parse(candidateJson()),
      ProviderCandidate.parse({
        ...candidateJson(id: 16),
        'mapPoint': {'latitude': 7.0, 'longitude': 80.0},
      }),
      ProviderCandidate.parse({...candidateJson(id: 17), 'mapPoint': null}),
    ];
    final pins = providerMapPins(
      candidates,
      searchPoint: const GeoPoint(6.92, 79.85),
    );
    expect(pins, hasLength(2));
    expect(pins.map((pin) => pin.displayLocation), [
      const LatLng(6.93, 79.86),
      const LatLng(7.0, 80.0),
    ]);
    expect(pins.every((pin) => !pin.separated), isTrue);
  });

  testWidgets(
    'coincident provider pins all retain icons and link to their shared real location',
    (tester) async {
      final candidates = [
        ProviderCandidate.parse(candidateJson()),
        ProviderCandidate.parse(candidateJson(id: 16)),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingLocationPicker(
                point: const GeoPoint(6.92, 79.85),
                candidates: candidates,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state;
      final providers = state.markers
          .where((m) => m.markerId.value.startsWith('provider-'))
          .toList();
      expect(providers, hasLength(2));
      expect(providers.map((m) => m.position).toSet(), hasLength(2));
      expect(state.polylines, hasLength(2));
      expect(
        state.polylines.every(
          (p) => p.points.first == const LatLng(6.93, 79.86),
        ),
        isTrue,
      );
      expect(
        providers.every(
          (m) => m.infoWindow.snippet!.contains('separated for visibility'),
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'provider markers retain coordinates, resolved icons and stable IDs',
    (tester) async {
      final row = candidateJson();
      row['mapMarker'] = {
        'icon': {'url': 'https://example.invalid/car.svg'},
      };
      final candidate = ProviderCandidate.parse(row);
      final icon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
      final requested = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
            customerMarkerIconLoaderProvider.overrideWithValue((url) async {
              requested.add(url);
              return icon;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingLocationPicker(
                point: const GeoPoint(6.92, 79.85),
                onChanged: (_) {},
                candidates: [candidate],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state;
      final marker = state.markers.singleWhere(
        (m) => m.markerId.value == 'provider-${candidate.key}',
      );
      expect(marker.position, const LatLng(6.93, 79.86));
      expect(marker.infoWindow.title, 'Provider 15');
      expect(marker.infoWindow.snippet, 'Approximate service area');
      expect(marker.icon, icon);
      expect(requested, ['https://example.invalid/car.svg']);
      expect(state.circles.single.radius, 5000);
    },
  );

  testWidgets('busy map disables tapping and dragging the selected location', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BookingLocationPicker(
              point: const GeoPoint(6.92, 79.85),
              enabled: false,
              onChanged: (_) => fail('Disabled location changed'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester
        .widget<CustomerTestMap>(find.byType(CustomerTestMap))
        .state;
    expect(state.onSelect, isNull);
    expect(state.markers.single.draggable, isFalse);
    expect(state.markers.single.onDragEnd, isNull);
    expect(find.byTooltip('Use current location'), findsNothing);
  });

  test(
    'native builder preserves Google controls and required legal attribution',
    () {
      // Test the real builder without mounting a native view in a widget test.
      const key = String.fromEnvironment('BTHERE_GOOGLE_MAPS_API_KEY');
      if (key.isEmpty) return;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final widget = container.read(customerMapBuilderProvider)(
        CustomerMapState(
          camera: const CameraPosition(target: LatLng(6.92, 79.85), zoom: 12),
          onCreated: (_) {},
          onSelect: (_) {},
          markers: const {},
          circles: const {},
        ),
      );
      expect(widget, isA<GoogleMap>());
      final map = widget as GoogleMap;
      expect(map.onTap, isNotNull);
      expect(map.myLocationButtonEnabled, isFalse);
      expect(map.mapToolbarEnabled, isFalse);
      expect(map.padding, EdgeInsets.zero);
    },
  );
}
