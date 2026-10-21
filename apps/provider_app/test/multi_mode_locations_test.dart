import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/application/registration_payload.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/presentation/registration_option_editor.dart';

import 'support/fake_schema_repository.dart';
import 'support/fake_registration_repository.dart';

const travel = 'PROVIDER_TO_CUSTOMER', premises = 'CUSTOMER_TO_PROVIDER';
Map<String, dynamic> area(String name, {num? radius, int? capacity}) => {
  'locationName': name,
  'latitude': 6.9,
  'longitude': 79.8,
  'radiusKm': radius,
  'capacity': capacity,
};
ProviderOnboardingSchema schema({
  String name = 'Service',
  List<String> modes = const [travel, premises, 'ONLINE'],
}) {
  final json = schemaJson();
  json['serviceSetup']['availabilityEnabled'] = false;
  json['options'] = [
    {
      'optionId': 12,
      'code': 'CUSTOM',
      'name': name,
      'fields': [],
      'deliveryModes': modes,
    },
  ];
  return parseProviderSchema(json, 3);
}

Map<String, dynamic> grouped() => {
  'locationsByMode': {
    travel: {
      'areas': [area('Coverage', radius: 10)],
    },
    premises: {
      'areas': [area('Studio', capacity: 4)],
    },
  },
};

class LocationRepository extends FakeRegistrationRepository {
  final modeLoads = <String>[];
  final modeResults = <String, Result<List<Map<String, dynamic>>>>{
    travel: Success([area('Saved coverage', radius: 8)]),
    premises: Success([area('Saved studio', capacity: 3)]),
  };
  @override
  Future<Result<List<Map<String, dynamic>>>> areas(
    int id,
    int optionId,
    String mode,
  ) async {
    modeLoads.add(mode);
    return modeResults[mode]!;
  }
}

Future<void> render(
  WidgetTester tester,
  ProviderOnboardingSchema config,
  Map<String, dynamic> initial,
  ValueChanged<Map<String, dynamic>> onSave, {
  LocationRepository? repository,
  bool registered = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          registrationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: RegistrationOptionEditor(
            asSheet: true,
            option: config.options.single,
            service: ProviderServiceType(
              id: 3,
              name: config.options.single.name,
              status: 'ACTIVE',
            ),
            setup: config.serviceSetup,
            initial: initial,
            assignmentId: registered ? 14 : null,
            loadSavedLocations: registered,
            onSave: (data) async => onSave(data),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text('Save $name Details'));
  await tester.tap(find.text('Save $name Details'));
  await tester.pumpAndSettle();
}

void main() {
  for (final name in [
    'Cat Care',
    'Caregiving',
    'Charging',
    'A new subservice',
  ]) {
    testWidgets(
      '$name renders all configured groups without a selector or false warning',
      (tester) async {
        Map<String, dynamic>? saved;
        await render(
          tester,
          schema(name: name),
          grouped(),
          (data) => saved = data,
        );
        expect(find.text('Customer coverage areas'), findsOneWidget);
        expect(find.text('Your service locations'), findsOneWidget);
        expect(find.textContaining('missing'), findsNothing);
        expect(find.textContaining('unavailable'), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await save(tester, name);
        expect(saved?['locationsByMode'], grouped()['locationsByMode']);
        expect(schema().options.single.validateLocations(saved!), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'saved locations load independently and failed group blocks replacement until retry',
    (tester) async {
      final repository = LocationRepository();
      repository.modeResults[premises] = const Failure(
        AppFailure(message: 'Temporary failure'),
      );
      Map<String, dynamic>? saved;
      await render(
        tester,
        schema(),
        {},
        (data) => saved = data,
        repository: repository,
        registered: true,
      );
      expect(repository.modeLoads, [travel, premises]);
      await save(tester, 'Service');
      expect(saved, isNull);
      expect(
        find.text('Load your saved locations before replacing them.'),
        findsOneWidget,
      );
      repository.modeResults[premises] = Success([
        area('Recovered studio', capacity: 2),
      ]);
      await tester.ensureVisible(find.text('Retry loading locations'));
      await tester.tap(find.text('Retry loading locations'));
      await tester.pumpAndSettle();
      await save(tester, 'Service');
      expect(
        saved?['locationsByMode'][travel]['areas'][0]['locationName'],
        'Saved coverage',
      );
      expect(
        saved?['locationsByMode'][premises]['areas'][0]['locationName'],
        'Recovered studio',
      );
      expect(repository.modeLoads, [travel, premises, premises]);
    },
  );
  testWidgets(
    'online only skips all physical location controls and saved location reads',
    (tester) async {
      final repository = LocationRepository();
      Map<String, dynamic>? saved;
      await render(
        tester,
        schema(modes: ['ONLINE']),
        {},
        (data) => saved = data,
        repository: repository,
        registered: true,
      );
      expect(find.text('Select Location'), findsNothing);
      expect(repository.modeLoads, isEmpty);
      await save(tester, 'Service');
      expect(saved?['deliveryMode'], 'ONLINE');
      expect(saved?['locationsByMode'], isEmpty);
    },
  );
  test('legacy drafts map only to their own group, never to another configured mode', () {
    final option = schema().options.single;
    final data = {
      'deliveryMode': travel,
      'areas': [area('Legacy coverage', radius: 5)],
    };
    final groups = option.locationGroups(data);
    expect(groups[travel]?['areas'], hasLength(1));
    expect(groups[premises]?['areas'], isEmpty);
    expect(option.validateLocations(data), isNotNull);
  });
  test('restoration preserves untouched saved groups and explicit local edits including clears', () {
    final restored = mergeRegistrationLocations(
      schema(),
      {'12': grouped()},
      {
        '12': {
          'locationsByMode': {
            travel: {
              'areas': [area('Edited coverage', radius: 12)],
            },
          },
        },
      },
    );
    expect(
      restored['12']['locationsByMode'][premises]['areas'][0]['locationName'],
      'Studio',
    );
    expect(
      restored['12']['locationsByMode'][travel]['areas'][0]['locationName'],
      'Edited coverage',
    );
    final cleared = mergeRegistrationLocations(
      schema(),
      {'12': grouped()},
      {
        '12': {'deliveryMode': travel, 'areas': <Object>[]},
      },
    );
    expect(cleared['12']['locationsByMode'][travel]['areas'], isEmpty);
    expect(cleared['12']['locationsByMode'][premises]['areas'], hasLength(1));
  });
  test('invalid coordinates and unknown configuration remain blocked instead of guessing', () {
    final data = grouped();
    (data['locationsByMode'] as Map)[travel]['areas'][0]['latitude'] =
        double.nan;
    expect(schema().options.single.validateLocations(data), isNotNull);
    expect(schema(modes: []).options.single.validateLocations({}), isNotNull);
    expect(
      schema(modes: ['FUTURE_MODE']).options.single.validateLocations({}),
      isNotNull,
    );
  });
}
