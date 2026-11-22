import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/domain/service_registration.dart';
import 'package:provider_app/features/services/application/registration_draft.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';

import '../service_draft_store_test.dart' show MemoryDraftStorage;
import 'fake_session_storage.dart';

class FakeRegistrationRepository extends RegistrationRepository {
  final shared = <int, Result<SharedOptionRegistration?>>{};
  final sharedLookups = <int>[];
  @override
  Future<Result<SharedOptionRegistration?>> sharedRegistration(
    int optionId,
  ) async {
    sharedLookups.add(optionId);
    return shared[optionId] ?? const Success(null);
  }

  FakeRegistrationRepository()
    : super(
        ApiClient(
          config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        ),
      );
  final writes = <String>[];
  List<Map<String, dynamic>>? submittedValues;
  Result<void> result = const Success(null);
  AppFailure? loadFailure;
  final areaLoads = <int>[];
  Result<List<Map<String, dynamic>>> areasResult = const Success([]);
  @override
  Future<Result<List<Map<String, dynamic>>>> areas(
    int id,
    int optionId,
    String mode,
  ) async {
    areaLoads.add(optionId);
    return areasResult;
  }

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
  ) async => loadFailure == null ? Success(server) : Failure(loadFailure!);
  @override
  Future<Result<void>> saveLanguages(int id, List<String> values) =>
      languages(id, values);
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
  final reviewHistory = <int, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> reviewUploads(int id) async =>
      reviewHistory[id] ?? {};
  @override
  Future<void> recordReviewUpload(int id, int typeId, String key) async {
    (reviewHistory[id] ??= {})['$typeId'] = key;
  }

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
