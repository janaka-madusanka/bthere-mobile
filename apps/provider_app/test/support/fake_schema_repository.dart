import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_schema_repository.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';

Map<String, dynamic> schemaJson({int id = 3}) => {
  'serviceTypeId': id,
  'serviceName': 'Home Nurse',
  'serviceSetup': {
    'serviceTypeId': id,
    'name': 'Home Nurse',
    'availabilityEnabled': true,
    'serviceAreasEnabled': true,
    'optionsRequired': true,
    'minimumOptionSelections': 1,
    'maximumOptionSelections': 5,
    'documents': [],
    'skills': [],
    'certificates': {'level': 'REQUIRED', 'requiresApproval': true},
    'education': {'level': 'OPTIONAL', 'requiresApproval': true},
  },
  'commonFields': [],
  'options': [],
};
Map<String, dynamic> fieldJson({int? optionId}) => {
  'fieldId': 7,
  'serviceTypeId': 3,
  'optionId': optionId,
  'scope': optionId == null ? 'COMMON' : 'OPTION',
  'code': 'INFO',
  'label': 'Information',
  'description': null,
  'fieldType': 'TEXT',
  'required': true,
  'requiresApproval': false,
  'minimumFiles': null,
  'maximumFiles': null,
  'maximumFileSizeMb': null,
  'allowedFileTypes': null,
  'options': null,
  'condition': null,
  'displayOrder': 0,
  'version': 1,
  'status': 'ACTIVE',
};

final class FakeSchemaRepository implements ProviderSchemaRepository {
  final List<int> calls = [];
  Result<ProviderOnboardingSchema>? result;
  Completer<Result<ProviderOnboardingSchema>>? pending;
  @override
  Future<Result<ProviderOnboardingSchema>> loadSchema(int id) async {
    calls.add(id);
    return pending != null
        ? pending!.future
        : result ?? Success(parseProviderSchema(schemaJson(id: id), id));
  }
}
