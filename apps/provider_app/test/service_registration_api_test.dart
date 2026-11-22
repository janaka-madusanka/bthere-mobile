import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/domain/service_registration.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_input.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'support/fake_session_storage.dart';
import 'support/fake_service_repository.dart' show assignmentJson;
import 'support/fake_completion_repository.dart' show completionJson;

void main() {
  late RegistrationAdapter adapter;
  late ApiClient client;
  late RegistrationRepository repository;
  setUp(() {
    adapter = RegistrationAdapter();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
    );
    repository = RegistrationRepository(client);
  });
  tearDown(() => client.close(force: true));
  test('atomic registration includes required empty collections and parses approval separately', () async {
    adapter.responses['/providers/me/service-registrations'] = {
      'assignment': assignmentJson(),
      'completion': completionJson(),
    };
    final result = await repository.register(
      const ServiceRegistrationInput(
        service: ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
        optionIds: [12],
        languages: ['ENGLISH'],
      ),
    );
    expect(result, isA<Success<ServiceRegistrationResult>>());
    final value = (result as Success<ServiceRegistrationResult>).value;
    expect(value.assignment.assignmentId, 14);
    expect(value.assignment.verificationStatus, 'PENDING');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.data['documents'], isEmpty);
    expect(request.data['certificates'], isEmpty);
    expect(request.data['education'], isEmpty);
    expect(request.data['unavailableDates'], isEmpty);
    expect(request.data['serviceAreas'], isEmpty);
    expect(request.data['requirements'], {'submissions': []});
    expect(request.data.containsKey('availability'), isFalse);
    expect(request.headers['Authorization'], 'Bearer synthetic-access');
  });
  test('shared option lookup returns original assignment; only 404 permits new enrollment', () async {
    adapter.responses['/providers/me/service-options/12/registration'] = {
      'optionId': 12,
      'providerOptionId': 80,
      'assignmentId': 140,
      'registrationServiceTypeId': 6,
      'providerStatus': 'ACTIVE',
      'adminStatus': 'ACTIVE',
      'verificationStatus': 'APPROVED',
    };
    final found = await repository.sharedRegistration(12);
    expect(
      (found as Success<SharedOptionRegistration?>).value!.assignmentId,
      140,
    );
    adapter.handler = (_) => ResponseBody.fromString(
      '{}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    expect(
      (await repository.sharedRegistration(
        12,
      ) as Success<SharedOptionRegistration?>).value,
      isNull,
    );
    adapter.handler = (_) => ResponseBody.fromString(
      '{}',
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    expect(
      await repository.sharedRegistration(12),
      isA<Failure<SharedOptionRegistration?>>(),
    );
  });
  test(
    'registration conflicts are returned without retry or approval reset',
    () async {
      adapter.handler = (_) => ResponseBody.fromString(
        '{}',
        409,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
      final result = await repository.register(
        const ServiceRegistrationInput(
          service: ProviderServiceInput(providerTypeId: 3, experienceYears: 0),
          optionIds: [12],
          languages: [],
        ),
      );
      expect(result, isA<Failure<ServiceRegistrationResult>>());
      expect(adapter.requests, hasLength(1));
    },
  );
}
