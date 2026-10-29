import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/services/data/registration_geocoder.dart';
import 'package:provider_app/features/services/data/registration_device_location.dart';

import 'support/fake_device_location.dart';

import 'package:provider_app/features/services/presentation/registration_location_editor.dart';

class FakeGeocoder implements RegistrationGeocoder {
  final requests = <String>[];
  final pending = <Completer<Map<String, dynamic>>>[];
  bool delay = false;
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    requests.add(query);
    return [
      {'locationName': 'Selected address', 'latitude': 6.9, 'longitude': 79.8},
    ];
  }

  @override
  Future<Map<String, dynamic>> reverse(double latitude, double longitude) {
    if (delay) {
      final request = Completer<Map<String, dynamic>>();
      pending.add(request);
      return request.future;
    }
    return Future.value({
      'locationName': 'Resolved address',
      'city': 'Resolved city',
      'country': 'Resolved country',
    });
  }
}

void main() {
  void mobile(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'map search saves coordinates, resolved address and radius without invented locations',
    (tester) async {
      mobile(tester);
      final geocoder = FakeGeocoder();
      Map<String, dynamic>? saved;
      RegistrationMapState? rendered;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registrationDeviceLocationProvider.overrideWithValue(
              FakeDeviceLocation(issue: DeviceLocationIssue.denied),
            ),
            appConfigProvider.overrideWithValue(
              AppConfig(
                apiBaseUrl: 'https://example.invalid/api/v1',
                googleMapsApiKey: 'sample',
              ),
            ),
            registrationGeocoderProvider.overrideWithValue(geocoder),
            registrationMapBuilderProvider.overrideWithValue((state) {
              rendered = state;
              return const ColoredBox(color: Colors.teal);
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showRegistrationLocation(
                      context,
                      mode: 'PROVIDER_TO_CUSTOMER',
                    );
                  },
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(rendered?.point, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('location-search')),
        'An actual search',
      );
      await tester.tap(find.byTooltip('Search locations'));
      await tester.pumpAndSettle();
      expect(geocoder.requests, ['An actual search']);
      await tester.tap(find.byKey(const ValueKey('location-result-0')));
      await tester.pumpAndSettle();
      expect(rendered?.point, const LatLng(6.9, 79.8));
      await tester.ensureVisible(find.byKey(const ValueKey('location-radius')));
      await tester.enterText(
        find.byKey(const ValueKey('location-radius')),
        '12.5',
      );
      await tester.pump();
      expect(rendered?.radiusKm, 12.5);
      await tester.ensureVisible(find.text('Save Location'));
      await tester.tap(find.text('Save Location'));
      await tester.pumpAndSettle();
      expect(saved?['latitude'], 6.9);
      expect(saved?['longitude'], 79.8);
      expect(saved?['radiusKm'], 12.5);
      expect(saved?['city'], 'Resolved city');
      expect(saved?['locationName'], 'Selected address');
    },
  );

  testWidgets(
    'moving the pin ignores stale address responses and premises have no radius',
    (tester) async {
      mobile(tester);
      final geocoder = FakeGeocoder()..delay = true;
      RegistrationMapState? rendered;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registrationDeviceLocationProvider.overrideWithValue(
              FakeDeviceLocation(issue: DeviceLocationIssue.denied),
            ),
            appConfigProvider.overrideWithValue(
              AppConfig(
                apiBaseUrl: 'https://example.invalid/api/v1',
                googleMapsApiKey: 'sample',
              ),
            ),
            registrationGeocoderProvider.overrideWithValue(geocoder),
            registrationMapBuilderProvider.overrideWithValue((state) {
              rendered = state;
              return const ColoredBox(color: Colors.teal);
            }),
          ],
          child: const MaterialApp(
            home: RegistrationLocationPicker(
              initial: {},
              mode: 'CUSTOMER_TO_PROVIDER',
            ),
          ),
        ),
      );
      await tester.pump();
      rendered!.onSelect(const LatLng(6, 79));
      await tester.pump();
      rendered!.onSelect(const LatLng(7, 80));
      await tester.pump();
      geocoder.pending[1].complete({'locationName': 'Newest selection'});
      await tester.pump();
      geocoder.pending[0].complete({'locationName': 'Stale selection'});
      await tester.pumpAndSettle();
      expect(find.text('Newest selection'), findsOneWidget);
      expect(find.text('Stale selection'), findsNothing);
      expect(rendered?.point, const LatLng(7, 80));
      expect(rendered?.radiusKm, isNull);
      expect(find.byKey(const ValueKey('location-radius')), findsNothing);
    },
  );
}
