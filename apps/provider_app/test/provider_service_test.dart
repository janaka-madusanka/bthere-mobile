import 'support/fake_schema_repository.dart';

import 'dart:async';
import 'dart:io';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/application/provider_completion_controller.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/services/application/provider_service_catalog_controller.dart';
import 'package:provider_app/features/onboarding/services/application/provider_service_selection_controller.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_remote_data_source.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_repository_impl.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_input.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_assignment.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';

import 'support/fake_service_repository.dart';
import 'support/fake_completion_repository.dart';
import 'support/fake_market_repository.dart';
import 'support/fake_session_storage.dart';
import 'provider_profile_test.dart' show ProfileAdapter;

class FailingImageClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Synthetic image failure; no network');
}

class FailingImageOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => FailingImageClient();
}

void main() {
  test('service catalog parses immutable active types and nullable optional fields', () {
    final values = parseActiveProviderServices([
      serviceJson(),
      serviceJson(id: 9)
        ..['description'] = null
        ..['iconUrl'] = null,
    ]);
    expect(values.first.id, 3);
    expect(values.first.name, 'Home Nurse');
    expect(values.first.description, 'Home nursing services');
    expect(values.first.status, 'ACTIVE');
    expect(values.last.description, isNull);
    expect(values.last.iconUrl, isNull);
    expect(() => values.clear(), throwsUnsupportedError);
    expect(
      parseActiveProviderServices([
        serviceJson()
          ..remove('description')
          ..remove('iconUrl'),
      ]).single.description,
      isNull,
    );
  });
  test('inactive types are excluded and empty active catalog is supported', () {
    expect(parseActiveProviderServices([]), isEmpty);
    expect(
      parseActiveProviderServices([serviceJson(status: 'INACTIVE')]),
      isEmpty,
    );
    expect(
      parseActiveProviderServices([
        serviceJson(status: 'INACTIVE'),
        serviceJson(id: 9),
      ]).single.id,
      9,
    );
  });
  for (final id in [null, 0, -1, 1.5, '3', true]) {
    test('invalid service ID $id is rejected', () {
      expect(
        () => parseActiveProviderServices([serviceJson()..['id'] = id]),
        throwsFormatException,
      );
    });
  }
  test('malformed catalog, duplicate IDs, blank names and invalid optional types fail safely', () {
    for (final value in [
      null,
      {},
      [null],
      [serviceJson(), serviceJson()],
    ]) {
      expect(() => parseActiveProviderServices(value), throwsFormatException);
    }
    for (final name in [null, '', '  ', 3]) {
      expect(
        () => parseActiveProviderServices([serviceJson()..['name'] = name]),
        throwsFormatException,
      );
    }
    expect(
      () => parseActiveProviderServices([serviceJson()..['description'] = 3]),
      throwsFormatException,
    );
    expect(
      () => parseActiveProviderServices([serviceJson()..['iconUrl'] = false]),
      throwsFormatException,
    );
  });
  test(
    'icon URLs are optional and only usable absolute HTTP URLs are shown',
    () {
      for (final url in [
        null,
        '',
        ' ',
        'bad url',
        '/relative.png',
        'file:///image',
        'https://user:password@example.invalid/icon',
      ]) {
        expect(
          parseActiveProviderServices([serviceJson()..['iconUrl'] = url])
              .single
              .usableIconUri,
          isNull,
        );
      }
      expect(
        parseActiveProviderServices([
          serviceJson()..['iconUrl'] = 'https://example.invalid/icon.png',
        ]).single.usableIconUri!.host,
        'example.invalid',
      );
    },
  );
  test(
    'assignment parses all documented fields and immutable document lists',
    () {
      final assignment = parseProviderServiceAssignment(assignmentJson());
      expect(assignment.assignmentId, 14);
      expect(assignment.providerTypeId, 3);
      expect(assignment.providerTypeName, 'Home Nurse');
      expect(assignment.experienceYears, 4.5);
      expect(assignment.status, 'ACTIVE');
      expect(assignment.providerStatus, 'ACTIVE');
      expect(assignment.adminStatus, 'ACTIVE');
      expect(assignment.verificationStatus, 'PENDING');
      expect(assignment.emergencyOverride, isFalse);
      expect(assignment.emergencyOverrideReason, isNull);
      expect(assignment.emergencyOverrideExpiresAt, isNull);
      expect(assignment.requiredDocumentTypeIds, [1, 2]);
      expect(assignment.missingDocumentTypeIds, [1, 2]);
      expect(
        () => assignment.requiredDocumentTypeIds.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => assignment.missingDocumentTypeIds.clear(),
        throwsUnsupportedError,
      );
      final override = parseProviderServiceAssignment(
        assignmentJson()
          ..['emergencyOverride'] = true
          ..['emergencyOverrideReason'] = 'Reviewed'
          ..['emergencyOverrideExpiresAt'] = '2030-01-02T12:00:00Z',
      );
      expect(override.emergencyOverrideReason, 'Reviewed');
      expect(override.emergencyOverrideExpiresAt, testNow);
    },
  );
  for (final id in [null, 0, -1, 1.5, '14', true]) {
    test('invalid assignment ID $id is rejected', () {
      expect(
        () => parseProviderServiceAssignment(
          assignmentJson()..['assignmentId'] = id,
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'assignment rejects malformed required fields, experience and document IDs',
    () {
      for (final key in [
        'providerTypeId',
        'providerTypeName',
        'experienceYears',
        'status',
        'providerStatus',
        'adminStatus',
        'verificationStatus',
        'emergencyOverride',
        'requiredDocumentTypeIds',
        'missingDocumentTypeIds',
      ]) {
        expect(
          () => parseProviderServiceAssignment(assignmentJson()..remove(key)),
          throwsFormatException,
          reason: key,
        );
      }
      for (final value in [-1, double.nan, double.infinity, '4.5']) {
        expect(
          () => parseProviderServiceAssignment(
            assignmentJson()..['experienceYears'] = value,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => parseProviderServiceAssignment(
          assignmentJson()..['requiredDocumentTypeIds'] = [0],
        ),
        throwsFormatException,
      );
      expect(
        () => parseProviderServiceAssignment(
          assignmentJson()
            ..['emergencyOverrideExpiresAt'] = 'private invalid date',
        ),
        throwsFormatException,
      );
    },
  );
  for (final text in [
    '',
    ' ',
    '-1',
    'NaN',
    'Infinity',
    '-Infinity',
    'not numeric',
    '1e9999',
  ]) {
    test('experience rejects $text', () {
      expect(ProviderServiceInput.parseExperience(text), isNull);
      expect(ProviderServiceInput.validateExperience(text), isNotNull);
    });
  }
  test('experience accepts zero, integers and decimals without an invented maximum', () {
    for (final text in ['0', '1', '2', '3.5', ' 4.5 ', '1000']) {
      final input = ProviderServiceInput(
        providerTypeId: 3,
        experienceYears: ProviderServiceInput.parseExperience(text)!,
      );
      expect(input.isValid, isTrue);
      expect(input.toJson(), {
        'providerTypeId': 3,
        'experienceYears': double.parse(text),
      });
      expect(input.toJson()['experienceYears'], isA<num>());
    }
  });

  late ProfileAdapter adapter;
  late ApiClient client;
  late FakeSessionStorage storage;
  late ProviderServiceRepositoryImpl repository;
  setUp(() {
    adapter = ProfileAdapter()..body = [serviceJson()];
    storage = FakeSessionStorage()..session = testSession();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
      adapter: adapter,
    );
    repository = ProviderServiceRepositoryImpl(
      ProviderServiceRemoteDataSource(client),
    );
  });
  tearDown(() => client.close(force: true));
  test(
    'GET provider-types uses requiresAuth and existing token bridge',
    () async {
      expect(
        await repository.loadActiveServices(),
        isA<Success<List<ProviderServiceType>>>(),
      );
      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/provider-types');
      expect(adapter.request!.extra['bthere.network.requires_auth'], isTrue);
      expect(
        adapter.request!.headers['Authorization'],
        'Bearer synthetic-access',
      );
    },
  );
  test('POST service-types sends exactly selected ID and numeric experience and parses assignment', () async {
    adapter.body = assignmentJson(typeId: 9);
    final result = await repository.addService(
      const ProviderServiceInput(providerTypeId: 9, experienceYears: 4.5),
    ) as Success<ProviderServiceAssignment>;
    expect(adapter.request!.method, 'POST');
    expect(adapter.request!.path, '/providers/me/service-types');
    expect(adapter.request!.extra['bthere.network.requires_auth'], isTrue);
    expect(
      adapter.request!.headers['Authorization'],
      'Bearer synthetic-access',
    );
    expect(adapter.request!.data, {
      'providerTypeId': 9,
      'experienceYears': 4.5,
    });
    expect(result.value.assignmentId, 14);
    expect(storage.writes, 0);
    expect(storage.clears, 0);
  });
  test(
    'repository handles empty and malformed catalog without fallback services',
    () async {
      adapter.body = [];
      expect(
        (await repository.loadActiveServices()
                as Success<List<ProviderServiceType>>)
            .value,
        isEmpty,
      );
      adapter.body = {'private': 'trace'};
      expect(
        (await repository.loadActiveServices()
                as Failure<List<ProviderServiceType>>)
            .failure
            .code,
        'SERVICE_INVALID_RESPONSE',
      );
    },
  );
  test('malformed or mismatched assignment fails safely', () async {
    for (final value in [
      null,
      assignmentJson()..['assignmentId'] = 0,
      assignmentJson(typeId: 9),
    ]) {
      adapter.body = value;
      final result = await repository.addService(
        const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
      ) as Failure<ProviderServiceAssignment>;
      expect(result.failure.code, 'SERVICE_INVALID_RESPONSE');
      expect(result.failure.cause, isNull);
    }
  });
  for (final status in [401, 500]) {
    test(
      'GET and POST HTTP $status safely map failures without modifying session',
      () async {
        adapter.status = status;
        adapter.body = {'message': 'private token trace'};
        final list =
            await repository.loadActiveServices()
                as Failure<List<ProviderServiceType>>;
        final post = await repository.addService(
          const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
        ) as Failure<ProviderServiceAssignment>;
        expect(list.failure.message, isNot(contains('private')));
        expect(post.failure.message, isNot(contains('private')));
        expect(storage.writes, 0);
        expect(storage.clears, 0);
      },
    );
  }
  test('repository rejects invalid input before transport and maps transport errors', () async {
    expect(
      await repository.addService(
        const ProviderServiceInput(providerTypeId: 0, experienceYears: -1),
      ),
      isA<Failure<ProviderServiceAssignment>>(),
    );
    expect(adapter.request, isNull);
    adapter.connectionFailure = true;
    final result =
        await repository.loadActiveServices()
            as Failure<List<ProviderServiceType>>;
    expect(result.failure.code, startsWith('NETWORK_'));
  });

  ProviderContainer scope(
    FakeServiceRepository repo,
    FakeCompletionRepository completion, {
    FakeSessionStorage? store,
  }) {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        sessionStorageProvider.overrideWithValue(
          store ?? (FakeSessionStorage()..session = testSession()),
        ),
        clockProvider.overrideWithValue(() => testNow),
        providerSchemaRepositoryProvider.overrideWithValue(
          FakeSchemaRepository(),
        ),
        providerServiceRepositoryProvider.overrideWithValue(repo),
        providerCompletionRepositoryProvider.overrideWithValue(completion),
        providerMarketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(),
        ),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No live API allowed'),
        ),
        googleIdentityProvider.overrideWith(
          (ref) => throw StateError('Google stays dormant'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  FakeCompletionRepository serviceCompletion() => FakeCompletionRepository()
    ..result = Success(
      parseProviderCompletion(completionJson(step: 'SELECT_SERVICE')),
    );
  Future<ProviderContainer> prepare(
    FakeServiceRepository repo,
    FakeCompletionRepository completion, {
    FakeSessionStorage? store,
  }) async {
    final container = scope(repo, completion, store: store);
    container.listen(providerServiceCatalogProvider, (_, _) {});
    container.listen(providerServiceSelectionProvider, (_, _) {});
    container.listen(providerCompletionControllerProvider, (_, _) {});
    await container.read(providerServiceCatalogProvider.future);
    await container.read(providerCompletionControllerProvider.future);
    return container;
  }

  test('controller blocks duplicate POST and retains assignment before completion reload', () async {
    final repo = FakeServiceRepository()
      ..pendingSubmit = Completer<Result<ProviderServiceAssignment>>();
    final completion = serviceCompletion();
    final container = await prepare(repo, completion);
    final controller = container.read(
      providerServiceSelectionProvider.notifier,
    );
    final future = controller.submit(
      const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
    );
    await controller.submit(
      const ProviderServiceInput(providerTypeId: 9, experienceYears: 2),
    );
    expect(repo.submissions, 1);
    expect(container.read(providerServiceSelectionProvider).loading, isTrue);
    expect(completion.calls, 1);
    repo.pendingSubmit!.complete(
      Success(parseProviderServiceAssignment(assignmentJson())),
    );
    await future;
    expect(
      container.read(providerServiceSelectionProvider).assignment!.assignmentId,
      14,
    );
    await container.read(providerCompletionControllerProvider.future);
    expect(completion.calls, 2);
    await controller.submit(
      const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
    );
    expect(repo.submissions, 1);
  });
  test('controller failure strips cause, permits retry and does not refresh completion', () async {
    final repo = FakeServiceRepository()
      ..submission = const Failure(
        AppFailure(message: 'Try again.', cause: 'private trace'),
      );
    final completion = serviceCompletion();
    final container = await prepare(repo, completion);
    final controller = container.read(
      providerServiceSelectionProvider.notifier,
    );
    await controller.submit(
      const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
    );
    expect(
      container.read(providerServiceSelectionProvider).failure!.cause,
      isNull,
    );
    expect(completion.calls, 1);
    repo.submission = null;
    await controller.submit(
      const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
    );
    await container.read(providerCompletionControllerProvider.future);
    expect(repo.submissions, 2);
    expect(completion.calls, 2);
  });
  test('controller rejects invalid experience and unlisted services', () async {
    final repo = FakeServiceRepository();
    final container = await prepare(repo, serviceCompletion());
    for (final input in [
      const ProviderServiceInput(providerTypeId: 99, experienceYears: 1),
      const ProviderServiceInput(providerTypeId: 3, experienceYears: -1),
      ProviderServiceInput(providerTypeId: 3, experienceYears: double.nan),
    ]) {
      await container
          .read(providerServiceSelectionProvider.notifier)
          .submit(input);
    }
    expect(repo.submissions, 0);
  });
  test('session changes clear assignment and late POST cannot update a new session', () async {
    final repo = FakeServiceRepository();
    final completion = serviceCompletion();
    final store = FakeSessionStorage()..session = testSession();
    final container = await prepare(repo, completion, store: store);
    await container
        .read(providerServiceSelectionProvider.notifier)
        .submit(
          const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
        );
    await container.read(providerCompletionControllerProvider.future);
    expect(
      container.read(providerServiceSelectionProvider).assignment,
      isNotNull,
    );
    store.session = null;
    container.invalidate(appSessionStateProvider);
    await container.read(appSessionStateProvider.future);
    expect(container.read(providerServiceSelectionProvider).assignment, isNull);
    expect(store.writes, 0);
    store.session = testSession();
    container.invalidate(appSessionStateProvider);
    await container.read(providerServiceCatalogProvider.future);
    await container.read(providerCompletionControllerProvider.future);
    repo.pendingSubmit = Completer<Result<ProviderServiceAssignment>>();
    final future = container
        .read(providerServiceSelectionProvider.notifier)
        .submit(
          const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
        );
    store.session = null;
    container.invalidate(appSessionStateProvider);
    await container.read(appSessionStateProvider.future);
    repo.pendingSubmit!.complete(
      Success(parseProviderServiceAssignment(assignmentJson())),
    );
    await future;
    expect(container.read(providerServiceSelectionProvider).assignment, isNull);
  });
  test(
    'unexpected catalog and submission exceptions become safe failures',
    () async {
      final repo = FakeServiceRepository()..throwLoad = true;
      final container = scope(repo, serviceCompletion());
      container.listen(providerServiceCatalogProvider, (_, _) {});
      final failure = await container.read(
        providerServiceCatalogProvider.future,
      ) as Failure<List<ProviderServiceType>>;
      expect(failure.failure.message, isNot(contains('private')));
      repo.throwLoad = false;
      container.read(providerServiceCatalogProvider.notifier).reload();
      await container.read(providerServiceCatalogProvider.future);
      container.listen(providerServiceSelectionProvider, (_, _) {});
      repo.throwSubmit = true;
      await container
          .read(providerServiceSelectionProvider.notifier)
          .submit(
            const ProviderServiceInput(providerTypeId: 3, experienceYears: 4.5),
          );
      expect(
        container.read(providerServiceSelectionProvider).failure!.message,
        isNot(contains('private')),
      );
    },
  );
}
