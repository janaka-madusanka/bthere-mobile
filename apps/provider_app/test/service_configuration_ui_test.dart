import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/presentation/registration_option_editor.dart';
import 'package:provider_app/features/services/presentation/registration_review.dart';
import 'package:provider_app/features/services/presentation/registration_widgets.dart';
import 'package:provider_app/features/services/presentation/service_catalog_visuals.dart';

import 'support/fake_schema_repository.dart';

void main() {
  testWidgets(
    'review uses configured labels and typed answers for every field type',
    (tester) async {
      final json = schemaJson()
        ..['commonFields'] = [
          {
            ...fieldJson(),
            'fieldId': 7,
            'label': 'Equipment notes',
            'fieldType': 'TEXTAREA',
          },
          {
            ...fieldJson(),
            'fieldId': 8,
            'label': 'Accessible site',
            'fieldType': 'BOOLEAN',
          },
          {
            ...fieldJson(),
            'fieldId': 9,
            'label': 'Connector',
            'fieldType': 'SELECT',
            'options': [
              {'label': 'Type Two', 'value': 'TYPE_2'},
            ],
          },
          {
            ...fieldJson(),
            'fieldId': 10,
            'label': 'Site photos',
            'fieldType': 'IMAGE_UPLOAD',
          },
        ];
      final value = ServiceDetailState(
        service: const ProviderServiceType(
          id: 3,
          name: 'Charging',
          status: 'ACTIVE',
        ),
        schema: parseProviderSchema(json, 3),
        selected: {},
        experience: '0',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegistrationReview(
                value: value,
                draft: const {
                  'fields': {
                    '7': 'Bring an adapter',
                    '8': false,
                    '9': 'TYPE_2',
                    '10': {
                      'files': [
                        {'key': 'private/photo.png'},
                      ],
                    },
                  },
                },
                onEdit: (_) {},
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [
        'Equipment notes',
        'Bring an adapter',
        'Accessible site',
        'No',
        'Connector',
        'Type Two',
        'Site photos',
        '1 uploaded file',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Service Description'), findsNothing);
      expect(find.text('private/photo.png'), findsNothing);
    },
  );

  for (final name in [
    'Caregiving',
    'Parking',
    'EV Charging',
    'Ride',
    'A new service',
  ]) {
    testWidgets(
      '$name uses configured fields without inferring behavior from names',
      (tester) async {
        final json = schemaJson();
        json['serviceSetup']['availabilityEnabled'] = false;
        json['serviceSetup']['serviceAreasEnabled'] = false;
        json['options'] = [
          {
            'optionId': 12,
            'code': 'CUSTOM',
            'name': name,
            'fields': [
              {
                ...fieldJson(optionId: 12),
                'fieldId': 7,
                'code': 'EXPERIENCE',
                'label': 'Experience with equipment',
                'required': false,
                'displayOrder': 2,
              },
              {
                ...fieldJson(optionId: 12),
                'fieldId': 8,
                'code': 'FIRST',
                'label': 'Configured first field',
                'required': false,
                'displayOrder': 1,
              },
              {
                ...fieldJson(optionId: 12),
                'fieldId': 9,
                'label': 'Customer booking input',
                'scope': 'BOOKING_FIELD',
              },
              {
                ...fieldJson(optionId: 12),
                'fieldId': 10,
                'label': 'Inactive requirement',
                'status': 'INACTIVE',
              },
            ],
          },
        ];
        final schema = parseProviderSchema(json, 3);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: RegistrationOptionEditor(
                option: schema.options.single,
                service: ProviderServiceType(
                  id: 3,
                  name: name,
                  status: 'ACTIVE',
                ),
                setup: schema.serviceSetup,
                initial: const {},
                loadSavedLocations: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Experience'), findsNothing);
        expect(find.text('Additional Information'), findsOneWidget);
        expect(find.text('Service Location & Area'), findsNothing);
        expect(find.text('Weekly Availability'), findsNothing);
        expect(find.text('Customer booking input'), findsNothing);
        expect(find.text('Inactive requirement'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Configured first field')).dy,
          lessThan(
            tester.getTopLeft(find.text('Experience with equipment')).dy,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$name does not show unconfigured review sections', (
      tester,
    ) async {
      final json = schemaJson();
      json['serviceSetup']['availabilityEnabled'] = false;
      json['serviceSetup']['serviceAreasEnabled'] = false;
      json['serviceSetup']['certificates']['level'] = 'DISABLED';
      json['serviceSetup']['education']['level'] = 'DISABLED';
      json['serviceSetup']['optionsRequired'] = false;
      json['serviceSetup']['minimumOptionSelections'] = 0;
      final value = ServiceDetailState(
        service: ProviderServiceType(id: 3, name: name, status: 'ACTIVE'),
        schema: parseProviderSchema(json, 3),
        selected: {},
        experience: '0',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegistrationReview(
                value: value,
                draft: const {},
                onEdit: (_) {},
                onSubmit: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Service Description',
        'Service Locations',
        'Service Area',
        'Skills',
        'Certifications',
        'Education',
        'Additional Documents',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text(name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing artwork uses neutral icons for every service name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            ServiceCatalogSymbol(
              service: const ProviderServiceType(
                id: 1,
                name: 'Caregiving',
                status: 'ACTIVE',
              ),
            ),
            ServiceCatalogSymbol(
              service: const ProviderServiceType(
                id: 2,
                name: 'Parking',
                status: 'ACTIVE',
              ),
            ),
            const RegistrationOptionSymbol('Hospital'),
            const RegistrationOptionSymbol('Elderly Care'),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.miscellaneous_services), findsNWidgets(2));
    expect(find.byIcon(Icons.work_outline), findsNWidgets(2));
  });
}
