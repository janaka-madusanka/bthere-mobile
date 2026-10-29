import 'dart:convert';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_remote_data_source.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_repository_impl.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/domain/service_registration.dart';
import 'package:provider_app/features/services/application/shared_option_route.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'registration_api_test.dart' show RegistrationAdapter;
import 'provider_options_test.dart' show optionsSchema;

import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';

import 'service_first_test.dart' show ServiceFixture, pump, path;
import 'support/fake_options_repository.dart' show selectedOptionJson;
import 'support/fake_registration_repository.dart';
import 'support/fake_session_storage.dart';
import 'support/fake_service_repository.dart' show serviceJson, assignmentJson;

import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';

void main() {
  for (final serviceId in [3, 9]) {
    testWidgets(
      'shared option is registered under linked service $serviceId and opens its profile',
      (tester) async {
        final fixture = ServiceFixture();
        fixture.services.catalog = Success(
          parseActiveProviderServices([
            serviceJson(id: 3),
            serviceJson(id: 9),
            serviceJson(id: 6, name: 'Source service'),
          ]),
        );
        fixture.services.assignments = Success([
          parseProviderServiceAssignment(
            assignmentJson(typeId: 6)..['assignmentId'] = 140,
          ),
        ]);
        final sourceSchema = optionsSchema();
        sourceSchema['serviceTypeId'] = 6;
        sourceSchema['serviceSetup']['serviceTypeId'] = 6;
        fixture.schema.resultsById[6] = Success(
          parseProviderSchema(sourceSchema, 6),
        );
        if (serviceId != 3) {
          final schema = optionsSchema();
          schema['serviceTypeId'] = serviceId;
          schema['serviceSetup']['serviceTypeId'] = serviceId;
          fixture.schema.result = Success(
            parseProviderSchema(schema, serviceId),
          );
        }
        final registration = fixture.container.read(
          registrationRepositoryProvider,
        ) as FakeRegistrationRepository;
        registration.shared[12] = const Success(
          SharedOptionRegistration(
            optionId: 12,
            providerOptionId: 80,
            assignmentId: 140,
            registrationServiceTypeId: 6,
            providerStatus: 'ACTIVE',
            adminStatus: 'ACTIVE',
            verificationStatus: 'APPROVED',
          ),
        );
        fixture.options.selectionsByAssignment[140] = Success(
          parseProviderOptions([
            selectedOptionJson()
              ..['providerOptionId'] = 80
              ..['verificationStatus'] = 'APPROVED',
          ]),
        );
        await pump(tester, fixture, route: '/services/$serviceId');
        final loaded = await fixture.container.read(
          serviceDetailControllerProvider(serviceId).future,
        );
        expect(loaded, isA<Success<ServiceDetailState>>());
        final value = (loaded as Success<ServiceDetailState>).value;
        expect(value.assignment, isNull);
        expect(value.registered.single.optionId, 12);
        expect(value.registrationSources[12]!.assignmentId, 140);
        expect(value.selected, isEmpty);
        expect(find.text('Your Registered Sub-services'), findsOneWidget);
        final row = find.byKey(const ValueKey('registered-option-12'));
        expect(row, findsOneWidget);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(path(fixture), AppRoutes.subServiceProfile(6, 12));
        expect(
          find.text('Your Work type 12 Service is Active!'),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(path(fixture), '/services/$serviceId');
        expect(fixture.services.submissions, 0);
        expect(fixture.options.saves, isEmpty);
        expect(registration.writes, isEmpty);
      },
    );
  }
  for (final status in ['PENDING', 'REJECTED', 'APPROVED']) {
    test(
      'shared routing preserves $status without navigating to main service',
      () {
        final source = SharedOptionRegistration(
          optionId: 137,
          providerOptionId: 813,
          assignmentId: 212,
          registrationServiceTypeId: 25,
          providerStatus: 'ACTIVE',
          adminStatus: 'ACTIVE',
          verificationStatus: status,
        );
        expect(
          sharedOptionRoute(source),
          status == 'APPROVED'
              ? AppRoutes.subServiceProfile(25, 137)
              : AppRoutes.serviceStatus(25),
        );
        if (status == 'PENDING') {
          expect(
            sharedOptionRoute(source, incomplete: true),
            '/services/25/register?optionId=137&details=1',
          );
        }
      },
    );
  }
  testWidgets('linked registration deep link opens the source without writes', (
    tester,
  ) async {
    final fixture = ServiceFixture();
    final registration = fixture.container.read(
      registrationRepositoryProvider,
    ) as FakeRegistrationRepository;
    registration.shared[12] = const Success(
      SharedOptionRegistration(
        optionId: 12,
        providerOptionId: 80,
        assignmentId: 140,
        registrationServiceTypeId: 6,
        providerStatus: 'ACTIVE',
        adminStatus: 'ACTIVE',
        verificationStatus: 'APPROVED',
      ),
    );
    fixture.options.selectionsByAssignment[140] = Success(
      parseProviderOptions([
        selectedOptionJson()
          ..['providerOptionId'] = 80
          ..['verificationStatus'] = 'APPROVED',
      ]),
    );
    await pump(
      tester,
      fixture,
      route: '/services/3/register?optionId=12&details=1',
    );
    expect(path(fixture), AppRoutes.subServiceProfile(6, 12));
    expect(fixture.services.submissions, 0);
    expect(fixture.options.saves, isEmpty);
    expect(registration.writes, isEmpty);
  });
  late RegistrationAdapter adapter;
  late ApiClient client;
  late ProviderOptionsRepositoryImpl repository;
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
    repository = ProviderOptionsRepositoryImpl(
      ProviderOptionsRemoteDataSource(client),
    );
  });
  tearDown(() => client.close(force: true));

  Map<String, dynamic> source(int optionId, int assignmentId, int serviceId) =>
      {
        'optionId': optionId,
        'providerOptionId': 800 + optionId,
        'assignmentId': assignmentId,
        'registrationServiceTypeId': serviceId,
        'providerStatus': 'ACTIVE',
        'adminStatus': 'ACTIVE',
        'verificationStatus': 'APPROVED',
      };
  ResponseBody response(Object? body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  for (final ids in [(12, 14, 3), (137, 212, 25)]) {
    test(
      'foreign shared option ${ids.$1} never writes to another assignment',
      () async {
        adapter.handler = (_) => response(source(ids.$1, ids.$2, ids.$3), 200);
        final result = await repository.saveSelections(ids.$2 + 1, [ids.$1]);
        expect(result, isA<Failure<void>>());
        expect(
          (result as Failure<void>).failure.code,
          'SHARED_OPTION_ALREADY_REGISTERED',
        );
        expect(
          adapter.requests.single.path,
          '/providers/me/service-options/${ids.$1}/registration',
        );
        expect(adapter.requests.single.method, 'GET');
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer synthetic-access',
        );
      },
    );
  }

  test('only lookup 404 permits enrollment; unavailable or malformed lookups block writes', () async {
    for (final status in [401, 403, 500, 200]) {
      adapter.requests.clear();
      adapter.handler = (_) => response({}, status);
      expect(await repository.saveSelections(14, [12]), isA<Failure<void>>());
      expect(adapter.requests.every((r) => r.method == 'GET'), true);
    }
  });

  test(
    'unchanged selections do not replay PUT or reset reviewed evidence',
    () async {
      adapter.handler = (request) => request.path.endsWith('/registration')
          ? response(source(12, 14, 3), 200)
          : response([
              selectedOptionJson()..['verificationStatus'] = 'APPROVED',
            ], 200);
      expect(await repository.saveSelections(14, [12]), isA<Success<void>>());
      expect(adapter.requests.every((r) => r.method == 'GET'), true);
    },
  );

  for (final status in [200, 204]) {
    test(
      'new selections use correct assignment PUT and accept $status',
      () async {
        adapter.handler = (request) => request.path.endsWith('/registration')
            ? response({}, 404)
            : response(
                request.method == 'GET' ? [] : [selectedOptionJson()],
                request.method == 'GET' ? 200 : status,
              );
        expect(await repository.saveSelections(27, [12]), isA<Success<void>>());
        final put = adapter.requests.last;
        expect(put.method, 'PUT');
        expect(put.path, '/providers/me/services/27/options');
        expect(put.data, {
          'optionIds': [12],
        });
      },
    );
  }

  for (final confirmed in [false, true]) {
    test('409 is success only with exact read-back: $confirmed', () async {
      var written = false;
      adapter.handler = (request) {
        if (request.path.endsWith('/registration')) return response({}, 404);
        if (request.method == 'PUT') {
          written = true;
          return response({'title': 'Resource conflict', 'status': 409}, 409);
        }
        return response(
          written && confirmed ? [selectedOptionJson()] : [],
          200,
        );
      };
      final result = await repository.saveSelections(14, [12]);
      expect(result, confirmed ? isA<Success<void>>() : isA<Failure<void>>());
      expect(adapter.requests.where((r) => r.method == 'PUT').length, 1);
      expect(adapter.requests.last.method, 'GET');
    });
  }

  test(
    'source lookup blocks assignment creation before a shared-option conflict',
    () async {
      final fixture = ServiceFixture();
      final registration = fixture.container.read(
        registrationRepositoryProvider,
      ) as FakeRegistrationRepository;
      registration.shared[12] = const Success(
        SharedOptionRegistration(
          optionId: 12,
          providerOptionId: 80,
          assignmentId: 140,
          registrationServiceTypeId: 6,
          providerStatus: 'ACTIVE',
          adminStatus: 'ACTIVE',
          verificationStatus: 'APPROVED',
        ),
      );
      final provider = serviceDetailControllerProvider(3);
      fixture.options.selectionsByAssignment[140] = Success(
        parseProviderOptions([
          selectedOptionJson()
            ..['providerOptionId'] = 80
            ..['verificationStatus'] = 'APPROVED',
        ]),
      );
      await fixture.container.read(provider.future);
      final controller = fixture.container.read(provider.notifier);
      controller.toggle(12);
      controller.experience('2');
      expect(await controller.continueSetup(), false);
      expect(fixture.services.submissions, 0);
      expect(fixture.options.saves, isEmpty);
    },
  );
}
