import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';

import 'support/fake_schema_repository.dart';

void main() {
  Map<String, dynamic> linkedSchema() => schemaJson(id: 1)
    ..['options'] = [
      for (final id in [7, 8, 9])
        {
          'optionId': id,
          'code': 'OPTION_$id',
          'name': 'Option $id',
          'fields': [fieldJson(optionId: id)],
        },
    ];

  test(
    'linked option fields preserve source service without parent metadata',
    () {
      final schema = parseProviderSchema(linkedSchema(), 1);
      expect(schema.serviceTypeId, 1);
      expect(schema.serviceSetup.serviceTypeId, 1);
      expect(schema.options[2].fields.single.serviceTypeId, 3);
      expect(schema.options[2].fields.single.optionIds, [9]);
    },
  );

  test(
    'linked fields still require valid IDs and matching option ownership',
    () {
      for (final value in [null, 0, -1, '3', 1.5]) {
        final json = linkedSchema();
        json['options'][2]['fields'][0]['serviceTypeId'] = value;
        expect(() => parseProviderSchema(json, 1), throwsFormatException);
      }
      final json = linkedSchema();
      json['options'][2]['fields'][0]['optionId'] = 8;
      expect(() => parseProviderSchema(json, 1), throwsFormatException);
    },
  );

  test('explicit option and field configuration IDs remain validated', () {
    final json = linkedSchema();
    json['options'][2]['configurationServiceTypeId'] = 1;
    expect(() => parseProviderSchema(json, 1), throwsFormatException);
    json['options'][2]['configurationServiceTypeId'] = 3;
    expect(
      parseProviderSchema(json, 1).options[2].fields.single.serviceTypeId,
      3,
    );
    json['options'][2]['fields'][0]['configurationServiceTypeId'] = 1;
    expect(() => parseProviderSchema(json, 1), throwsFormatException);
  });

  test('common fields still require matching service ownership', () {
    final json = linkedSchema()..['commonFields'] = [fieldJson()];
    expect(() => parseProviderSchema(json, 1), throwsFormatException);
  });
}
