import 'support/fake_options_repository.dart';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/application/provider_completion_controller.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_remote_data_source.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_repository_impl.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_requirement_section.dart';
import 'package:provider_app/features/onboarding/requirements/application/provider_requirements_controller.dart';

import 'provider_profile_test.dart' show ProfileAdapter;
import 'support/fake_schema_repository.dart';
import 'support/fake_completion_repository.dart';
import 'support/fake_session_storage.dart';

ProviderContainer scope(
  FakeCompletionRepository completion,
  FakeSchemaRepository schema,
) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
    ),
    clockProvider.overrideWithValue(() => testNow),
    sessionStorageProvider.overrideWithValue(
      FakeSessionStorage()..session = testSession(),
    ),
    providerCompletionRepositoryProvider.overrideWithValue(completion),
    providerSchemaRepositoryProvider.overrideWithValue(schema),
    providerOptionsRepositoryProvider.overrideWithValue(
      FakeOptionsRepository(),
    ),
    apiClientProvider.overrideWith((_) => throw StateError('No live backend')),
  ],
);
FakeCompletionRepository completionRepo() => FakeCompletionRepository()
  ..result = Success(
    parseProviderCompletion(
      completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS'),
    ),
  );
void main() {
  test('schema parses sample with immutable nullable and nested data', () {
    final json = schemaJson()..['commonFields'] = [fieldJson()];
    final schema = parseProviderSchema(json, 3);
    expect(schema.serviceTypeId, 3);
    expect(schema.commonFields.single.description, isNull);
    expect(schema.commonFields.single.allowedFileTypes, isEmpty);
    expect(() => schema.options.clear(), throwsUnsupportedError);
    expect(() => schema.commonFields.clear(), throwsUnsupportedError);
  });
  for (final value in [null, 0, -1, 1.5, '3', true]) {
    test('rejects malformed schema id $value', () {
      expect(
        () => parseProviderSchema(schemaJson()..['serviceTypeId'] = value, 3),
        throwsFormatException,
      );
    });
  }
  for (final value in ['DISABLED', 'OPTIONAL', 'REQUIRED']) {
    test('level $value remains exact', () {
      final j = schemaJson();
      j['serviceSetup']['certificates']['level'] = value;
      expect(
        parseProviderSchema(j, 3).serviceSetup.certificates.level.name,
        value.toLowerCase(),
      );
    });
  }
  test('unknown level fails rather than fallback', () {
    final j = schemaJson();
    j['serviceSetup']['education']['level'] = 'FUTURE';
    expect(
      () => parseProviderSchema(j, 3),
      throwsA(isA<UnsupportedRequirementMetadata>()),
    );
  });
  test('common and option fields retain metadata and ownership', () {
    final j = schemaJson()
      ..['commonFields'] = [fieldJson()]
      ..['options'] = [
        {
          'optionId': 9,
          'code': 'A',
          'name': 'Option',
          'fields': [
            fieldJson(optionId: 9)
              ..['options'] = [
                {'value': 'a'},
              ]
              ..['condition'] = {'field': 'INFO'},
          ],
        },
      ];
    final s = parseProviderSchema(j, 3);
    expect(s.commonFields.single.optionId, isNull);
    expect(s.options.single.fields.single.optionId, 9);
    expect(
      () => (s.options.single.fields.single.options as List).clear(),
      throwsUnsupportedError,
    );
    j['options'][0]['fields'][0]['optionId'] = 8;
    expect(() => parseProviderSchema(j, 3), throwsFormatException);
  });
  test('invalid bounds and nested identifiers are rejected', () {
    for (final key in ['minimumOptionSelections', 'serviceTypeId']) {
      final j = schemaJson();
      j['serviceSetup'][key] = -1;
      expect(() => parseProviderSchema(j, 3), throwsFormatException);
    }
  });
  test('all applicable rows use authoritative flags, no language or fabricated requiredness', () {
    final j = schemaJson()..['commonFields'] = [fieldJson()];
    j['serviceSetup']['documents'] = [
      {'metadata': []},
    ];
    j['serviceSetup']['skills'] = [
      {'metadata': []},
    ];
    final c = parseProviderCompletion(completionJson());
    final rows = requirementRows(parseProviderSchema(j, 3), c.services.single);
    expect(rows.length, 8);
    expect(rows.where((r) => r.completed).length, 5);
    expect(rows.first.completed, c.services.single.optionsCompleted);
    expect(
      rows
          .firstWhere((r) => r.section == ProviderRequirementSection.documents)
          .level,
      isNull,
    );
    expect(rows.map((r) => r.section.slug), isNot(contains('languages')));
  });
  test('disabled sections and false enable flags excluded', () {
    final j = schemaJson();
    final s = j['serviceSetup'];
    s['availabilityEnabled'] = false;
    s['serviceAreasEnabled'] = false;
    s['optionsRequired'] = false;
    s['certificates']['level'] = 'DISABLED';
    s['education']['level'] = 'DISABLED';
    expect(
      requirementRows(
        parseProviderSchema(j, 3),
        parseProviderCompletion(completionJson()).services.single,
      ),
      isEmpty,
    );
  });
  test(
    'selectable options and option fields independently enable sections',
    () {
      final j = schemaJson()
        ..['options'] = [
          {
            'optionId': 9,
            'code': 'A',
            'name': 'Option',
            'fields': [fieldJson(optionId: 9)],
          },
        ];
      j['serviceSetup']['optionsRequired'] = false;
      final rows = requirementRows(
        parseProviderSchema(j, 3),
        parseProviderCompletion(completionJson()).services.single,
      );
      expect(
        rows.map((r) => r.section),
        containsAll([
          ProviderRequirementSection.options,
          ProviderRequirementSection.additional,
        ]),
      );
    },
  );
  test('GET exact endpoint authenticated using session bridge', () async {
    final a = ProfileAdapter()..body = schemaJson();
    final storage = FakeSessionStorage()..session = testSession();
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
      adapter: a,
    );
    addTearDown(() => client.close(force: true));
    final repo = ProviderSchemaRepositoryImpl(
      ProviderSchemaRemoteDataSource(client),
    );
    expect(await repo.loadSchema(3), isA<Success<ProviderOnboardingSchema>>());
    expect(a.request!.path, '/provider-types/3/onboarding-schema');
    expect(a.request!.extra['bthere.network.requires_auth'], true);
    expect(a.request!.headers['Authorization'], 'Bearer synthetic-access');
    a.body = schemaJson()..['serviceTypeId'] = 4;
    expect(await repo.loadSchema(3), isA<Failure<ProviderOnboardingSchema>>());
    a.connectionFailure = true;
    expect(await repo.loadSchema(3), isA<Failure<ProviderOnboardingSchema>>());
  });
  test('restored session recovers assignment without temporary selection and reuses completion', () async {
    final c = completionRepo(), s = FakeSchemaRepository();
    final container = scope(c, s);
    addTearDown(container.dispose);
    await container.read(providerCompletionControllerProvider.future);
    final result = await container.read(
      providerRequirementsControllerProvider.future,
    ) as Success<ProviderRequirementsOverview>;
    expect(result.value.selected.assignmentId, 14);
    expect(result.value.selected.serviceTypeId, 3);
    expect(c.calls, 1);
    expect(s.calls, [3]);
    container.read(providerRequirementsControllerProvider.notifier).refresh();
    await container.read(providerRequirementsControllerProvider.future);
    expect(c.calls, 2);
    expect(s.calls, [3, 3]);
  });
  test('missing assignment returns safe empty failure', () async {
    final c = completionRepo();
    c.result = Success(
      parseProviderCompletion(
        completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS')
          ..['services'] = [],
      ),
    );
    final s = FakeSchemaRepository(), container = scope(c, s);
    addTearDown(container.dispose);
    expect(
      await container.read(providerRequirementsControllerProvider.future),
      isA<Failure<ProviderRequirementsOverview>>(),
    );
    expect(s.calls, isEmpty);
  });
  test(
    'multiple assignments sorted and selected with authoritative IDs',
    () async {
      final json = completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS');
      final service = Map<String, dynamic>.from(json['services'][0])
        ..['assignmentId'] = 2
        ..['serviceTypeId'] = 9
        ..['serviceName'] = 'Caregiver';
      json['services'] = [json['services'][0], service];
      final c = completionRepo()
        ..result = Success(parseProviderCompletion(json));
      final s = FakeSchemaRepository(), container = scope(c, s);
      addTearDown(container.dispose);
      var result = await container.read(
        providerRequirementsControllerProvider.future,
      ) as Success<ProviderRequirementsOverview>;
      expect(result.value.selected.assignmentId, 2);
      container
          .read(providerRequirementsControllerProvider.notifier)
          .select(14);
      result = await container.read(
        providerRequirementsControllerProvider.future,
      ) as Success<ProviderRequirementsOverview>;
      expect(result.value.selected.assignmentId, 14);
      expect(s.calls, [9, 3]);
    },
  );

  for (final category in ['certificates', 'education']) {
    for (final level in ['DISABLED', 'OPTIONAL', 'REQUIRED']) {
      test('$category applicability $level', () {
        final j = schemaJson();
        j['serviceSetup'][category]['level'] = level;
        final rows = requirementRows(
          parseProviderSchema(j, 3),
          parseProviderCompletion(completionJson()).services.single,
        );
        final matches = rows.where((r) => r.section.slug == category);
        expect(matches.length, level == 'DISABLED' ? 0 : 1);
        if (matches.isNotEmpty) {
          expect(matches.single.level!.name, level.toLowerCase());
        }
      });
    }
  }
  test('public model constructors deep copy metadata', () {
    final metadata = <String, Object?>{
      'nested': <Object?>[1],
    };
    final document = ProviderDocumentRequirement(metadata);
    (metadata['nested'] as List).add(2);
    expect(document.metadata['nested'], [1]);
    expect(
      () => (document.metadata['nested'] as List).clear(),
      throwsUnsupportedError,
    );
  });
  test('schema repository reports unsupported metadata and rejects invalid IDs before transport', () async {
    final adapter = ProfileAdapter()..body = schemaJson();
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
      adapter: adapter,
    );
    addTearDown(() => client.close(force: true));
    final repo = ProviderSchemaRepositoryImpl(
      ProviderSchemaRemoteDataSource(client),
    );
    expect(await repo.loadSchema(0), isA<Failure<ProviderOnboardingSchema>>());
    expect(adapter.request, isNull);
    final j = schemaJson();
    j['serviceSetup']['certificates']['level'] = 'UNKNOWN';
    adapter.body = j;
    final result =
        await repo.loadSchema(3) as Failure<ProviderOnboardingSchema>;
    expect(result.failure.code, 'SCHEMA_UNSUPPORTED_METADATA');
    expect(result.failure.cause, isNull);
  });
  test(
    'a fresh container restores completion rather than remembering assignments',
    () async {
      final c = completionRepo(), schema = FakeSchemaRepository();
      final first = scope(c, schema);
      await first.read(providerRequirementsControllerProvider.future);
      first.dispose();
      final second = scope(c, schema);
      addTearDown(second.dispose);
      final result = await second.read(
        providerRequirementsControllerProvider.future,
      ) as Success<ProviderRequirementsOverview>;
      expect(result.value.selected.assignmentId, 14);
      expect(c.calls, 2);
      expect(schema.calls, [3, 3]);
    },
  );
  test(
    'completion failure prevents schema access and strips private cause',
    () async {
      final c = completionRepo()
        ..result = const Failure(
          AppFailure(message: 'Safe failure', cause: 'private'),
        );
      final schema = FakeSchemaRepository(), container = scope(c, schema);
      addTearDown(container.dispose);
      final result = await container.read(
        providerRequirementsControllerProvider.future,
      ) as Failure<ProviderRequirementsOverview>;
      expect(result.failure.cause, isNull);
      expect(schema.calls, isEmpty);
    },
  );
}
