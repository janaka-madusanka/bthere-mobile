import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/services/application/registration_payload.dart';

import 'support/fake_schema_repository.dart';

void main() {
  test(
    'public subservices follow configured order regardless of names or IDs',
    () {
      final json = schemaJson()
        ..['options'] = [
          {'optionId': 12, 'code': 'A', 'name': 'Care', 'fields': []},
          {'optionId': 13, 'code': 'B', 'name': 'Charging', 'fields': []},
        ];
      final schema = applyPublicOptions(parseProviderSchema(json, 3), [
        {'optionId': 12, 'code': 'A', 'name': 'Renamed A', 'displayOrder': 2},
        {'optionId': 13, 'code': 'B', 'name': 'Renamed B', 'displayOrder': 1},
      ]);
      expect(schema.options.map((o) => o.optionId), [13, 12]);
    },
  );

  test('deselected option answers never override selected option answers', () {
    final draft = <String, dynamic>{
      'fields': {'1': 'Common'},
      'options': {
        '12': {
          'fields': {'7': 'Current answer'},
        },
        '13': {
          'fields': {'7': 'Stale answer', '8': 'Removed answer'},
        },
      },
    };
    expect(registrationAnswers(draft, selected: {12}), {
      '1': 'Common',
      '7': 'Current answer',
    });
    expect(registrationAnswers(draft, selected: {}), {'1': 'Common'});
  });

  test(
    'location mode comes from configuration and overrides stale choices',
    () {
      final json = schemaJson()
        ..['options'] = [
          {
            'optionId': 12,
            'code': 'CARE',
            'name': 'Care',
            'fields': [],
            'deliveryModes': ['PROVIDER_TO_CUSTOMER'],
          },
        ];
      final option = parseProviderSchema(json, 3).options.single;
      expect(option.configuredLocationMode(), 'PROVIDER_TO_CUSTOMER');
      expect(option.configuredLocationMode('ONLINE'), 'PROVIDER_TO_CUSTOMER');
      final draft = {
        'languages': ['ENGLISH'],
        'availability': {'availableAnyDay': true},
        'options': {
          '12': {
            'areas': [
              {'latitude': 6.9, 'longitude': 79.8, 'radiusKm': 5},
            ],
          },
        },
      };
      expect(
        validateRegistrationDraft(parseProviderSchema(json, 3), {12}, draft),
        isNull,
      );
    },
  );

  test('public option configuration retains fixed location capacity', () {
    final json = schemaJson()
      ..['options'] = [
        {'optionId': 12, 'code': 'EV', 'name': 'Charging', 'fields': []},
      ];
    final schema = applyPublicOptions(parseProviderSchema(json, 3), [
      {
        'optionId': 12,
        'code': 'EV',
        'name': 'Charging',
        'locationEnabled': false,
        'defaultCapacity': 8,
        'bookingMode': 'MANY_AT_A_TIME',
        'deliveryModes': ['CUSTOMER_TO_PROVIDER'],
      },
    ]);
    final option = schema.options.single;
    expect(option.defaultCapacity, 8);
    expect(option.bookingMode, 'MANY_AT_A_TIME');
    expect(option.usesServiceAreas(schema.serviceSetup), isFalse);
    expect(
      validateRegistrationDraft(
        schema,
        {12},
        {
          'languages': ['ENGLISH'],
          'availability': {'availableAnyDay': true},
        },
      ),
      isNull,
    );
  });
  test(
    'email and calendar date validation accepts valid configured answers',
    () {
      final email = field({...fieldJson(), 'fieldType': 'EMAIL'}, 3, null);
      final date = field({...fieldJson(), 'fieldType': 'DATE'}, 3, null);
      expect(validateRegistrationAnswer(email, 'provider@example.com'), isNull);
      expect(validateRegistrationAnswer(email, 'invalid'), isNotNull);
      expect(validateRegistrationAnswer(date, '2026-10-20'), isNull);
      expect(validateRegistrationAnswer(date, '2026-02-30'), isNotNull);
    },
  );
  test('select answers reject values removed from configuration', () {
    final select = field(
      {
        ...fieldJson(),
        'fieldType': 'MULTI_SELECT',
        'options': [
          {'label': 'Type 2', 'value': 'TYPE_2'},
        ],
      },
      3,
      null,
    );
    expect(validateRegistrationAnswer(select, ['TYPE_2']), isNull);
    expect(validateRegistrationAnswer(select, ['OLD']), isNotNull);
    expect(validateRegistrationAnswer(select, 'TYPE_2'), isNotNull);
  });
}
