import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';

import 'fake_service_repository.dart';
import 'fake_schema_repository.dart';
import 'fake_options_repository.dart';

FakeServiceRepository configuredServiceRepository() => FakeServiceRepository()
  ..assignments = Success([parseProviderServiceAssignment(assignmentJson())]);
FakeSchemaRepository configuredSchemaRepository() => FakeSchemaRepository()
  ..result = Success(
    parseProviderSchema(
      schemaJson()
        ..['options'] = [
          {'optionId': 12, 'code': 'HOME', 'name': 'Home care', 'fields': []},
        ],
      3,
    ),
  );
FakeOptionsRepository configuredOptionsRepository() =>
    FakeOptionsRepository()
      ..selections = Success(parseProviderOptions([selectedOptionJson()]));
