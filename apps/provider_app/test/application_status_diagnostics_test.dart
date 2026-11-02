import 'dart:convert';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/services/application/application_status_controller.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/document_models.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'service_first_test.dart' show ServiceFixture, completeServiceJson;
import 'provider_options_test.dart' show optionsSchema;
import 'support/fake_documents_repository.dart';
import 'support/fake_session_storage.dart';

import 'package:provider_app/core/auth/session_access_token_provider.dart';

void main() {
  test(
    'documents preserve verification when optional upload metadata is absent',
    () {
      for (final omitted in [true, false]) {
        final raw = documentJson(status: 'APPROVED');
        if (omitted) {
          raw.remove('documentNumber');
          raw.remove('issuedDate');
        } else {
          raw['documentNumber'] = null;
          raw['issuedDate'] = null;
        }
        final document = parseDocuments([raw]).single;
        expect(document.number, '');
        expect(document.issuedDate, '');
        expect(document.id, 70);
        expect(document.key, raw['documentKey']);
        expect(document.verificationStatus, 'APPROVED');
        expect(document.status(DateTime(2030)), 'Approved');
      }
    },
  );

  test('status loads documents with absent optional metadata without losing review state', () async {
    final fixture = ServiceFixture(existing: true);
    (fixture.container.read(
      documentsRepositoryProvider,
    ) as FakeDocuments).requirementsResult = const Success([
      DocumentRequirement(1, 'Identity document', null, false, true, true),
    ]);
    fixture.completion.result = Success(
      parseProviderCompletion(completeServiceJson()),
    );
    (fixture.container.read(
      documentsRepositoryProvider,
    ) as FakeDocuments).documentsResult = Success(
      parseDocuments([
        documentJson()
          ..['documentNumber'] = null
          ..['issuedDate'] = null,
      ]),
    );
    final result = await fixture.container.read(
      applicationStatusProvider(3).future,
    );
    expect(result, isA<Success<ApplicationStatusData>>());
    final data = (result as Success<ApplicationStatusData>).value;
    expect(data.pending, true);
    expect(
      data.items.firstWhere((item) => item.id == 'document-1').state,
      ApplicationItemState.pending,
    );
    expect(fixture.services.submissions, 0);
    expect(fixture.options.saves, isEmpty);
  });
  test(
    'document diagnostics identify the rejected field without its value',
    () {
      for (final key in [
        'documentId',
        'documentTypeName',
        'documentName',
        'documentNumber',
        'issuedDate',
        'createdAt',
      ]) {
        final value = documentJson()..[key] = {'private': 'sensitive-value'};
        expect(
          () => parseDocuments([value]),
          throwsA(
            isA<InvalidSchemaValue>().having(
              (error) => error.path,
              'path',
              'documents[0].$key',
            ),
          ),
        );
      }
    },
  );
  test('status diagnostics identify invalid review metadata without response values', () async {
    final fixture = ServiceFixture(existing: true);
    fixture.completion.result = Success(
      parseProviderCompletion(completeServiceJson()),
    );
    final schema = optionsSchema();
    schema['serviceSetup']['skills'] = [
      {
        'skillId': 10,
        'required': true,
        'name': {'private': 'sensitive-value'},
      },
    ];
    fixture.schema.result = Success(parseProviderSchema(schema, 3));
    final messages = <String>[];
    final container = ProviderContainer(
      parent: fixture.container,
      overrides: [
        applicationStatusDiagnosticLoggerProvider.overrideWithValue(
          messages.add,
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(applicationStatusProvider(3).future),
      isA<Failure<ApplicationStatusData>>(),
    );
    expect(
      messages.join(),
      contains(
        'stage=review-items outcome=invalid-path:serviceSetup.skills[0].name',
      ),
    );
    expect(messages.join(), isNot(contains('sensitive-value')));
  });

  test('status diagnostics distinguish failed document response from review processing', () async {
    final fixture = ServiceFixture(existing: true);
    fixture.completion.result = Success(
      parseProviderCompletion(completeServiceJson()),
    );
    (fixture.container.read(
      documentsRepositoryProvider,
    ) as FakeDocuments).documentsResult = const Failure(
      AppFailure(message: 'sensitive-value'),
    );
    final messages = <String>[];
    final container = ProviderContainer(
      parent: fixture.container,
      overrides: [
        applicationStatusDiagnosticLoggerProvider.overrideWithValue(
          messages.add,
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(applicationStatusProvider(3).future),
      isA<Failure<ApplicationStatusData>>(),
    );
    expect(messages.join(), contains('stage=documents outcome=failed'));
    expect(messages.join(), isNot(contains('sensitive-value')));
  });

  test('HTTP 200 with malformed snapshot logs the resource and never becomes empty success', () async {
    final adapter = RegistrationAdapter()
      ..handler = (request) => ResponseBody.fromString(
        jsonEncode(
          request.path.endsWith('/skills')
              ? {'private': 'sensitive-value'}
              : request.path.endsWith('/availability')
              ? <String, Object?>{}
              : [],
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
    );
    addTearDown(() => client.close(force: true));
    final messages = <String>[];
    final repository = RegistrationRepository(
      client,
      diagnosticLogger: messages.add,
    );
    final result = await repository.load(
      27,
      parseProviderSchema(optionsSchema(), 3).serviceSetup,
    );
    expect(result, isA<Failure<Map<String, dynamic>>>());
    expect(
      messages.join(),
      contains('resource=skills outcome=invalid-response'),
    );
    expect(messages.join(), isNot(contains('sensitive-value')));
  });

  test(
    'HTTP 200 malformed documents reports its parser independently',
    () async {
      final adapter = RegistrationAdapter()
        ..handler = (_) => ResponseBody.fromString(
          '{"private":"sensitive-value"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        adapter: adapter,
        tokenProvider: SessionAccessTokenProvider(
          FakeSessionStorage()..session = testSession(),
          now: () => testNow,
        ),
      );
      addTearDown(() => client.close(force: true));
      final messages = <String>[];
      final repository = ApiDocumentsRepository(
        client,
        diagnosticLogger: messages.add,
      );
      expect(await repository.documents(), isA<Failure>());
      expect(
        messages.join(),
        contains('resource=documents outcome=invalid-response'),
      );
      expect(messages.join(), isNot(contains('sensitive-value')));
    },
  );
}
