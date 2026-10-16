import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/data/registration_device_location.dart';
import 'package:provider_app/features/services/data/registration_geocoder.dart';
import 'package:provider_app/features/services/presentation/registration_location_editor.dart';
import 'package:provider_app/features/services/presentation/registration_option_editor.dart';

import 'registration_location_test.dart' show FakeGeocoder;
import 'support/fake_device_location.dart';
import 'support/fake_registration_repository.dart';
import 'support/fake_schema_repository.dart';

void main() {
  for (final registered in [false, true]) {
    testWidgets(
      '${registered ? 'existing' : 'new'} option handles saved-location reads safely',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FakeRegistrationRepository()
          ..areasResult = const Failure(
            AppFailure(message: 'Option not registered'),
          );
        final schema = schemaJson();
        schema['serviceSetup']['availabilityEnabled'] = false;
        Map<String, dynamic>? saved;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              registrationRepositoryProvider.overrideWithValue(repository),
              registrationDeviceLocationProvider.overrideWithValue(
                FakeDeviceLocation(),
              ),
              registrationGeocoderProvider.overrideWithValue(FakeGeocoder()),
              appConfigProvider.overrideWithValue(
                AppConfig(
                  apiBaseUrl: 'https://example.invalid/api/v1',
                  googleMapsApiKey: 'sample',
                ),
              ),
              registrationMapBuilderProvider.overrideWithValue(
                (_) => const ColoredBox(color: Colors.teal),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open option'),
                    onPressed: () async {
                      saved = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => RegistrationOptionEditor(
                                option: ProviderSchemaOption(
                                  optionId: 4,
                                  code: 'HOSPITAL',
                                  name: 'Hospital Caregiver',
                                  fields: [],
                                  deliveryModes: ['CUSTOMER_TO_PROVIDER'],
                                ),
                                service: const ProviderServiceType(
                                  id: 1,
                                  name: 'Caregiver',
                                  status: 'ACTIVE',
                                ),
                                assignmentId: 2,
                                loadSavedLocations: registered,
                                setup: parseProviderSchema(
                                  schema,
                                  3,
                                ).serviceSetup,
                                initial: {
                                  'deliveryMode': 'CUSTOMER_TO_PROVIDER',
                                  'areas': <Object>[],
                                },
                              ),
                            ),
                          );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open option'));
        await tester.pumpAndSettle();
        expect(repository.areaLoads, registered ? [4] : isEmpty);
        if (registered) {
          expect(find.text('Retry loading locations'), findsOneWidget);
          await tester.ensureVisible(
            find.text('Save Hospital Caregiver Details'),
          );
          await tester.tap(find.text('Save Hospital Caregiver Details'));
          await tester.pumpAndSettle();
          expect(saved, isNull);
          expect(
            find.text('Load your saved locations before replacing them.'),
            findsOneWidget,
          );
        } else {
          expect(find.text('Retry loading locations'), findsNothing);
          await tester.ensureVisible(find.text('Select Location'));
          await tester.tap(find.text('Select Location'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save Location'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byIcon(Icons.add));
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text('Save Hospital Caregiver Details'),
          );
          await tester.tap(find.text('Save Hospital Caregiver Details'));
          await tester.pumpAndSettle();
          expect(saved?['saved'], isTrue);
          expect(saved?['areas'], hasLength(1));
          expect(saved?['areas'][0]['latitude'], 6.9);
          expect(saved?['areas'][0]['longitude'], 79.8);
          expect(repository.areaLoads, isEmpty);
          expect(repository.writes, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
