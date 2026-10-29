import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/services/data/registration_device_location.dart';
import 'package:provider_app/features/services/data/registration_geocoder.dart';
import 'package:provider_app/features/services/presentation/registration_location_editor.dart';

import 'registration_location_test.dart' show FakeGeocoder;
import 'support/fake_device_location.dart';

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('HomeInter', 'Inter.ttf'),
      ('Nunito', 'Nunito.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$asset'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late RegistrationMapState rendered;
  Future<void> pump(
    WidgetTester tester,
    FakeDeviceLocation device, {
    Map<String, dynamic> initial = const {},
    FakeGeocoder? geocoder,
    bool overview = false,
    List<Map<String, dynamic>> areas = const [],
  }) async {
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(
              apiBaseUrl: 'https://example.invalid/api/v1',
              googleMapsApiKey: 'sample',
            ),
          ),
          registrationDeviceLocationProvider.overrideWithValue(device),
          registrationGeocoderProvider.overrideWithValue(
            geocoder ?? FakeGeocoder(),
          ),
          registrationMapBuilderProvider.overrideWithValue((state) {
            rendered = state;
            return const ColoredBox(
              color: Color(0xFFE9F1ED),
              child: Center(
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFF00858D),
                  size: 42,
                ),
              ),
            );
          }),
        ],
        child: MaterialApp(
          home: overview
              ? Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showRegistrationAreas(
                        context,
                        areas,
                        'PROVIDER_TO_CUSTOMER',
                      ),
                      child: const Text('View in Map'),
                    ),
                  ),
                )
              : RegistrationLocationPicker(
                  initial: initial,
                  mode: 'PROVIDER_TO_CUSTOMER',
                ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final size in [const Size(320, 640), const Size(430, 932)]) {
    testWidgets(
      'picker fits map address radius and save without scrolling at $size',
      (tester) async {
        await pump(
          tester,
          FakeDeviceLocation(),
          initial: {
            'latitude': 6.9,
            'longitude': 79.8,
            'locationName': 'Kovilakanda, Central Province, Sri Lanka',
            'radiusKm': 10,
          },
        );
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('location-picker-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        expect(find.text('50 km').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('location-radius')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Save Location').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new location uses GPS and resolves an address without coordinate inputs',
    (tester) async {
      final device = FakeDeviceLocation();
      await pump(tester, device);
      await tester.pumpAndSettle();
      expect(device.calls, 1);
      expect(rendered.point, device.position);
      expect(find.text('Resolved address'), findsOneWidget);
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Longitude'), findsNothing);
      expect(find.text('Country'), findsNothing);
      await tester.ensureVisible(find.text('15 km'));
      await tester.tap(find.text('15 km'));
      await tester.pump();
      expect(rendered.radiusKm, 15);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preset, slider and exact radius update the same map state', (
    tester,
  ) async {
    await pump(tester, FakeDeviceLocation());
    await tester.pumpAndSettle();
    expect(rendered.radiusKm, 5);
    await tester.ensureVisible(find.text('25 km'));
    await tester.tap(find.text('25 km'));
    await tester.pumpAndSettle();
    expect(rendered.radiusKm, 25);
    final slider = find.byKey(const ValueKey('location-radius-slider'));
    await tester.ensureVisible(slider);
    tester.widget<Slider>(slider).onChanged!(12.5);
    await tester.pumpAndSettle();
    expect(rendered.radiusKm, 12.5);
    final input = find.byKey(const ValueKey('location-radius'));
    expect(tester.widget<TextFormField>(input).controller!.text, '12.5');
    await tester.ensureVisible(input);
    await tester.enterText(input, '75.25');
    await tester.pumpAndSettle();
    expect(rendered.radiusKm, 75.25);
    expect(tester.widget<Slider>(slider).max, 75.25);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late GPS response cannot overwrite a manually selected pin', (
    tester,
  ) async {
    final device = FakeDeviceLocation()..pending = Completer<LatLng>();
    await pump(tester, device);
    rendered.onSelect(const LatLng(7, 80));
    await tester.pumpAndSettle();
    device.pending!.complete(const LatLng(8, 81));
    await tester.pumpAndSettle();
    expect(rendered.point, const LatLng(7, 80));
  });
  testWidgets('editing a saved pin preserves it and does not request GPS', (
    tester,
  ) async {
    final device = FakeDeviceLocation();
    await pump(
      tester,
      device,
      initial: {
        'latitude': 7.1,
        'longitude': 80.1,
        'locationName': 'Saved address',
        'radiusKm': 10,
      },
    );
    await tester.pumpAndSettle();
    expect(device.calls, 0);
    expect(rendered.point, const LatLng(7.1, 80.1));
    expect(find.text('Saved address'), findsOneWidget);
  });
  testWidgets('permanent denial offers settings while leaving search enabled', (
    tester,
  ) async {
    final device = FakeDeviceLocation(issue: DeviceLocationIssue.deniedForever);
    await pump(tester, device);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Settings'));
    await tester.tap(find.text('Open Settings'));
    expect(device.settings, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('location-search')));
    await tester.enterText(
      find.byKey(const ValueKey('location-search')),
      'A city',
    );
    await tester.ensureVisible(find.byTooltip('Search locations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search locations'));
    await tester.pumpAndSettle();
    expect(find.text('6.9, 79.8'), findsNothing);
    expect(find.byKey(const ValueKey('location-result-0')), findsOneWidget);
  });
  testWidgets(
    'coverage map lists locations and switches selected coverage without GPS',
    (tester) async {
      final device = FakeDeviceLocation();
      await pump(
        tester,
        device,
        overview: true,
        areas: [
          {
            'latitude': 6.9,
            'longitude': 79.8,
            'locationName': 'First location',
            'radiusKm': 10,
          },
          {
            'latitude': 7.1,
            'longitude': 80.1,
            'locationName': 'Second location',
            'radiusKm': 25,
          },
        ],
      );
      await tester.tap(find.text('View in Map'));
      await tester.pumpAndSettle();
      expect(rendered.readOnly, isTrue);
      expect(rendered.markers, hasLength(2));
      expect(rendered.circles, hasLength(2));
      await tester.ensureVisible(find.byKey(const ValueKey('saved-area-1')));
      await tester.tap(find.byKey(const ValueKey('saved-area-1')));
      await tester.pumpAndSettle();
      expect(rendered.point, const LatLng(7.1, 80.1));
      expect(rendered.radiusKm, 25);
      expect(device.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final overview in [false, true]) {
    testWidgets(
      '${overview ? 'coverage' : 'picker'} uses themed layout and supports large text',
      (tester) async {
        await pump(
          tester,
          FakeDeviceLocation(),
          overview: overview,
          initial: {
            'latitude': 6.9,
            'longitude': 79.8,
            'locationName': 'Selected address',
            'radiusKm': 15,
          },
          areas: [
            {
              'latitude': 6.9,
              'longitude': 79.8,
              'locationName': 'Selected address',
              'radiusKm': 15,
            },
          ],
        );
        if (overview) await tester.tap(find.text('View in Map'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(
            'goldens/location_${overview ? 'coverage' : 'picker'}.png',
          ),
        );
        tester.view.physicalSize = const Size(320, 640);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(overview ? 'Done' : 'Save Location'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('empty coverage uses a useful empty state and no map', (
    tester,
  ) async {
    await pump(tester, FakeDeviceLocation(), overview: true);
    await tester.tap(find.text('View in Map'));
    await tester.pumpAndSettle();
    expect(find.text('No service locations yet'), findsOneWidget);
    expect(find.text('Show all locations'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
