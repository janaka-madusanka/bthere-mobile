import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/application/registration_draft.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';

import '../service_draft_store_test.dart' show MemoryDraftStorage;
import 'fake_session_storage.dart';

class FakeRegistrationRepository extends RegistrationRepository {
  FakeRegistrationRepository()
    : super(
        ApiClient(
          config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        ),
      );
  final writes = <String>[];
  List<Map<String, dynamic>>? submittedValues;
  Result<void> result = const Success(null);
  Map<String, dynamic> server = {
    'languages': <String>[],
    'skills': <Object>[],
    'submissions': <Object>[],
    'availability': {
      'availableAnyDay': false,
      'availableAnyTime': true,
      'weeklySlots': <Object>[],
    },
    'certificates': <Object>[],
    'education': <Object>[],
  };
  @override
  Future<Result<Map<String, dynamic>>> load(
    int id,
    ProviderServiceSetup setup,
  ) async => Success(server);
  @override
  Future<Result<void>> languages(int id, List<String> values) async {
    writes.add('languages');
    return result;
  }

  @override
  Future<Result<void>> skills(int id, List<int> ids) async {
    writes.add('skills');
    return result;
  }

  @override
  Future<Result<void>> availability(int id, Map<String, dynamic> values) async {
    writes.add('availability');
    return result;
  }

  @override
  Future<Result<void>> saveAreas(
    int id,
    int optionId,
    String mode,
    List<Map<String, dynamic>> areas,
  ) async {
    writes.add('areas');
    return result;
  }

  @override
  Future<Result<void>> submissions(
    int id,
    List<Map<String, dynamic>> values,
  ) async {
    writes.add('submissions');
    submittedValues = values;
    return result;
  }

  @override
  Future<Object?> read(int id, String resource) async => server[resource] ?? [];
}

class MemoryRegistrationDrafts extends RegistrationDraftStore {
  MemoryRegistrationDrafts()
    : super(FakeSessionStorage(), MemoryDraftStorage());
  final drafts = <int, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(int id) async => drafts[id] ?? {};
  @override
  Future<void> write(int id, Map<String, dynamic> value) async {
    drafts[id] = value;
  }
}

Map<String, dynamic> readyRegistrationDraft() => {
  'languages': ['ENGLISH'],
  'skills': <String>[],
  'availability': {
    'availableAnyDay': true,
    'availableAnyTime': true,
    'weeklySlots': <Object>[],
  },
  'options': {
    '12': {'deliveryMode': 'ONLINE', 'areas': <Object>[], 'saved': true},
  },
};
