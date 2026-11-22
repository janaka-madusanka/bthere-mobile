import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/application/provider_requirements_controller.dart';
import 'package:provider_app/features/onboarding/requirements/options/application/provider_options_controller.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_remote_data_source.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_repository_impl.dart';
import 'package:provider_app/features/onboarding/requirements/options/domain/provider_selected_option.dart';

import 'provider_profile_test.dart' show ProfileAdapter;
import 'registration_api_test.dart' show RegistrationAdapter;

import 'dart:convert';

import 'provider_requirements_test.dart' show scope, completionRepo;
import 'support/fake_options_repository.dart';
import 'support/fake_schema_repository.dart';
import 'support/fake_completion_repository.dart';
import 'support/fake_session_storage.dart';

Map<String, dynamic> optionsSchema({
  bool required = true,
  int? min = 1,
  int? max = 3,
  bool fields = false,
}) {
  final j = schemaJson();
  j['serviceSetup'] = Map<String, dynamic>.from(j['serviceSetup']);
  j['serviceSetup']['optionsRequired'] = required;
  j['serviceSetup']['minimumOptionSelections'] = min;
  j['serviceSetup']['maximumOptionSelections'] = max;
  j['options'] = [
    for (final id in [12, 13, 14])
      {
        'optionId': id,
        'code': 'PRIVATE_CODE_$id',
        'name': 'Work type $id',
        'fields': fields && id == 12 ? [fieldJson(optionId: 12)] : [],
      },
  ];
  return j;
}

final optionsProvider = providerOptionsControllerProvider(
  const ProviderOptionsContext(14, 3),
);
ProviderContainer optionsScope(
  FakeOptionsRepository options, {
  FakeSchemaRepository? schema,
  FakeCompletionRepository? completion,
}) {
  final parent = scope(
    completion ?? completionRepo(),
    schema ??
        (FakeSchemaRepository()
          ..result = Success(parseProviderSchema(optionsSchema(), 3))),
  );
  final child = ProviderContainer(
    parent: parent,
    overrides: [providerOptionsRepositoryProvider.overrideWithValue(options)],
  );
  addTearDown(parent.dispose);
  addTearDown(child.dispose);
  return child;
}

Future<ProviderOptionsState> loaded(ProviderContainer c) async => (await c.read(
  optionsProvider.future,
) as Success<ProviderOptionsState>).value;

void main() {
  test('selected option immutable model parses approval metadata and empty selections', () {
    final j = selectedOptionJson()
      ..['reviewedBy'] = 7
      ..['reviewedAt'] = '2030-01-02T12:00:00Z'
      ..['reviewNote'] = 'Approved';
    final values = parseProviderOptions([j]);
    expect(values.single.optionId, 12);
    expect(values.single.providerOptionId, 112);
    expect(values.single.verificationStatus, 'PENDING');
    expect(values.single.reviewedAt, DateTime.utc(2030, 1, 2, 12));
    expect(values.single.reviewedBy, 7);
    expect(values.single.reviewNote, 'Approved');
    expect(() => values.clear(), throwsUnsupportedError);
    expect(parseProviderOptions([]), isEmpty);
    expect(
      parseProviderOptions([selectedOptionJson()]).single.reviewedAt,
      isNull,
    );
  });
  for (final key in ['providerOptionId', 'optionId']) {
    for (final id in [null, 0, -1, 1.5, '12', true]) {
      test('selected $key rejects $id', () {
        expect(
          () => parseProviderOptions([selectedOptionJson()..[key] = id]),
          throwsFormatException,
        );
      });
    }
  }
  test('malformed selected list, duplicate IDs and invalid review metadata rejected', () {
    for (final raw in [
      null,
      {},
      [null],
      [selectedOptionJson(), selectedOptionJson()],
    ]) {
      expect(() => parseProviderOptions(raw), throwsFormatException);
    }
    for (final key in [
      'code',
      'name',
      'providerStatus',
      'adminStatus',
      'verificationStatus',
    ]) {
      expect(
        () => parseProviderOptions([selectedOptionJson()..[key] = '']),
        throwsFormatException,
      );
    }
    expect(
      () => parseProviderOptions([
        selectedOptionJson()..['reviewedAt'] = 'invalid',
      ]),
      throwsFormatException,
    );
    expect(
      () => parseProviderOptions([selectedOptionJson()..['reviewNote'] = 3]),
      throwsFormatException,
    );
  });
  test('GET and PUT exact authenticated endpoints, integer payload and 204 success', () async {
    final adapter = RegistrationAdapter()
      ..handler = (request) => ResponseBody.fromString(
        request.path.endsWith('/registration')
            ? '{}'
            : request.method == 'GET'
            ? jsonEncode([selectedOptionJson()])
            : '',
        request.path.endsWith('/registration')
            ? 404
            : request.method == 'GET'
            ? 200
            : 204,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final repo = ProviderOptionsRepositoryImpl(
      ProviderOptionsRemoteDataSource(client),
    );
    expect(
      await repo.loadSelections(42),
      isA<Success<List<ProviderSelectedOption>>>(),
    );
    expect(adapter.requests.last.path, '/providers/me/services/42/options');
    expect(adapter.requests.last.method, 'GET');
    expect(adapter.requests.last.extra['bthere.network.requires_auth'], true);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer synthetic-access',
    );
    expect(await repo.saveSelections(42, [12, 13]), isA<Success<void>>());
    expect(adapter.requests.last.method, 'PUT');
    expect(adapter.requests.last.path, '/providers/me/services/42/options');
    expect(adapter.requests.last.extra['bthere.network.requires_auth'], true);
    expect(adapter.requests.last.data, {
      'optionIds': [12, 13],
    });
    expect(
      (adapter.requests.last.data['optionIds'] as List).every((v) => v is int),
      true,
    );
  });
  test('repository invalid input fails before transport', () async {
    final adapter = ProfileAdapter();
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final repo = ProviderOptionsRepositoryImpl(
      ProviderOptionsRemoteDataSource(client),
    );
    expect(
      await repo.loadSelections(-1),
      isA<Failure<List<ProviderSelectedOption>>>(),
    );
    for (final ids in [
      [0],
      [12, 12],
    ]) {
      expect(await repo.saveSelections(14, ids), isA<Failure<void>>());
    }
    expect(adapter.request, isNull);
  });
  test('GET and PUT network failures are normalized', () async {
    final adapter = ProfileAdapter()..connectionFailure = true;
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final repo = ProviderOptionsRepositoryImpl(
      ProviderOptionsRemoteDataSource(client),
    );
    expect(
      await repo.loadSelections(14),
      isA<Failure<List<ProviderSelectedOption>>>(),
    );
    expect(await repo.saveSelections(14, [12]), isA<Failure<void>>());
  });
  test('existing selected IDs preselected with pending approval', () async {
    final repo = FakeOptionsRepository()
      ..selections = Success(parseProviderOptions([selectedOptionJson()]));
    final c = optionsScope(repo);
    final v = await loaded(c);
    expect(v.selected, {12});
    expect(v.validation, isNull);
    expect(repo.loads, [14]);
  });
  test('unknown saved option surfaces inconsistency and blocks save', () async {
    final repo = FakeOptionsRepository()
      ..selections = Success(
        parseProviderOptions([selectedOptionJson(id: 99)]),
      );
    final c = optionsScope(repo);
    final v = await loaded(c);
    expect(v.inconsistent, true);
    expect(v.selected, isEmpty);
    c.read(optionsProvider.notifier).toggle(12);
    await c.read(optionsProvider.notifier).save();
    expect(repo.saves, isEmpty);
  });
  test(
    'schema min and max validate zero, one and multiple selections',
    () async {
      final repo = FakeOptionsRepository(),
          c = optionsScope(
            repo,
            schema: FakeSchemaRepository()
              ..result = Success(
                parseProviderSchema(optionsSchema(min: 2, max: 2), 3),
              ),
          );
      await loaded(c);
      final controller = c.read(optionsProvider.notifier);
      expect((await loaded(c)).validation, contains('at least 2'));
      controller.toggle(12);
      expect((await loaded(c)).validation, isNotNull);
      controller.toggle(13);
      expect((await loaded(c)).validation, isNull);
      controller.toggle(14);
      expect((await loaded(c)).validation, contains('no more than 2'));
      await controller.save();
      expect(repo.saves, isEmpty);
    },
  );
  test(
    'optional null limits permit empty selection and no invented maximum',
    () async {
      final repo = FakeOptionsRepository(),
          c = optionsScope(
            repo,
            schema: FakeSchemaRepository()
              ..result = Success(
                parseProviderSchema(
                  optionsSchema(required: false, min: null, max: null),
                  3,
                ),
              ),
          );
      expect((await loaded(c)).validation, isNull);
      final controller = c.read(optionsProvider.notifier);
      for (final id in [12, 13, 14]) {
        controller.toggle(id);
      }
      expect((await loaded(c)).validation, isNull);
      for (final id in [12, 13, 14]) {
        controller.toggle(id);
      }
      await controller.save();
      expect(repo.saves.single.ids, isEmpty);
    },
  );
  test('required missing minimum blocks save without guessing', () async {
    final repo = FakeOptionsRepository(),
        c = optionsScope(
          repo,
          schema: FakeSchemaRepository()
            ..result = Success(
              parseProviderSchema(optionsSchema(min: null), 3),
            ),
        );
    await loaded(c);
    c.read(optionsProvider.notifier).toggle(12);
    expect((await loaded(c)).validation, contains('unavailable'));
    await c.read(optionsProvider.notifier).save();
    expect(repo.saves, isEmpty);
  });
  test('duplicate save blocked and PUT failure preserves selections', () async {
    final repo = FakeOptionsRepository()
      ..pendingSave = Completer<Result<void>>();
    final c = optionsScope(repo);
    await loaded(c);
    final controller = c.read(optionsProvider.notifier);
    controller.toggle(13);
    controller.toggle(12);
    final pending = controller.save();
    await controller.save();
    controller.toggle(14);
    expect(repo.saves.length, 1);
    expect(repo.saves.single.ids, [12, 13]);
    repo.pendingSave!.complete(
      const Failure(AppFailure(message: 'Try again', cause: 'private')),
    );
    await pending;
    final v = await loaded(c);
    expect(v.selected, {12, 13});
    expect(v.failure!.message, 'Try again');
    expect(v.failure!.cause, isNull);
    expect(v.saving, false);
  });
  test('successful save reloads completion and schema, location flag follows backend', () async {
    final completion = completionRepo(),
        schema = FakeSchemaRepository()
          ..result = Success(parseProviderSchema(optionsSchema(), 3));
    final repo = FakeOptionsRepository();
    repo.onSave = () {
      final j = completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS');
      j['services'][0]['optionsCompleted'] = true;
      j['services'][0]['serviceAreasCompleted'] = false;
      completion.result = Success(parseProviderCompletion(j));
    };
    final c = optionsScope(repo, schema: schema, completion: completion);
    await loaded(c);
    c.read(optionsProvider.notifier).toggle(12);
    await c.read(optionsProvider.notifier).save();
    final overview = await c.read(
      providerRequirementsControllerProvider.future,
    ) as Success<ProviderRequirementsOverview>;
    expect(completion.calls, 2);
    expect(schema.calls, [3, 3]);
    expect(overview.value.selected.optionsCompleted, true);
    expect(overview.value.selected.serviceAreasCompleted, false);
  });
  test('schema still refreshes when completion moves to review', () async {
    final completion = completionRepo(),
        schema = FakeSchemaRepository()
          ..result = Success(parseProviderSchema(optionsSchema(), 3));
    final repo = FakeOptionsRepository();
    repo.onSave = () {
      final j = completionJson(step: 'AWAIT_ADMIN_APPROVAL');
      for (final key in [
        'documentsCompleted',
        'skillsCompleted',
        'certificatesCompleted',
        'educationCompleted',
        'availabilityCompleted',
        'serviceAreasCompleted',
        'optionsCompleted',
        'customRequirementsCompleted',
      ]) {
        j['services'][0][key] = true;
      }
      completion.result = Success(parseProviderCompletion(j));
    };
    final c = optionsScope(repo, schema: schema, completion: completion);
    await loaded(c);
    c.read(optionsProvider.notifier).toggle(12);
    await c.read(optionsProvider.notifier).save();
    expect(completion.calls, 2);
    expect(schema.calls, [3, 3]);
  });
}
