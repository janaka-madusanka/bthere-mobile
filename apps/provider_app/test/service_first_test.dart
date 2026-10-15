import 'package:provider_app/features/account/application/provider_profile_overview.dart';

import 'support/fake_documents_repository.dart';
import 'support/completed_entry_gate.dart';

import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';

import 'package:provider_app/features/services/documents/documents_controller.dart';

import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/domain/provider_completion.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_repository_impl.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_remote_data_source.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_assignment.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_requirement_section.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/application/service_setup_controller.dart';
import 'package:provider_app/features/services/application/service_providers.dart';
import 'package:provider_app/features/services/domain/sub_service_rules.dart';
import 'package:provider_app/features/services/domain/provider_service_status.dart';

import 'provider_profile_test.dart' show ProfileAdapter, input;

import 'package:provider_app/features/onboarding/profile/application/provider_profile_controller.dart';
import 'package:provider_app/features/onboarding/markets/application/provider_market_controller.dart';

import 'provider_options_test.dart' show optionsSchema;
import 'support/fake_service_repository.dart';
import 'support/fake_schema_repository.dart';
import 'support/fake_options_repository.dart';
import 'support/fake_completion_repository.dart';
import 'support/fake_profile_repository.dart';
import 'support/fake_market_repository.dart';
import 'support/fake_session_storage.dart';
import 'support/fake_registration_repository.dart';

import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/application/registration_draft.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_reader.dart';

class ServiceFixture {
  final services = FakeServiceRepository(),
      schema = FakeSchemaRepository(),
      options = FakeOptionsRepository(),
      completion = FakeCompletionRepository(),
      storage = FakeSessionStorage()..session = testSession();
  late ProviderContainer container;
  ServiceFixture({
    bool existing = false,
    Map<String, dynamic> profileData = const {},
    FakeProfileRepository? profileRepository,
    ProfileSupplementRepository? profileSupplementRepository,
    bool signedIn = true,
    String step = 'COMPLETE_PROFILE',
  }) {
    if (!signedIn) storage.session = null;
    schema.result = Success(parseProviderSchema(optionsSchema(), 3));
    completion.result = Success(
      parseProviderCompletion(
        completionJson(step: step)
          ..['services'] = existing ? completionJson()['services'] : [],
      ),
    );
    if (existing) {
      services.assignments = Success([
        parseProviderServiceAssignment(assignmentJson()),
      ]);
      options.selections = Success(
        parseProviderOptions([selectedOptionJson()]),
      );
    }
    options.onSave = () {
      options.selections = Success(
        parseProviderOptions(
          options.saves.last.ids
              .map((id) => selectedOptionJson(id: id))
              .toList(),
        ),
      );
      final j = completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS');
      j['services'][0]['optionsCompleted'] = true;
      j['services'][0]['serviceAreasCompleted'] = false;
      completion.result = Success(parseProviderCompletion(j));
    };
    container = ProviderContainer(
      overrides: [
        if (profileSupplementRepository != null)
          profileSupplementRepositoryProvider.overrideWithValue(
            profileSupplementRepository,
          ),
        registrationRepositoryProvider.overrideWithValue(
          FakeRegistrationRepository(),
        ),
        registrationDraftStoreProvider.overrideWithValue(
          MemoryRegistrationDrafts(),
        ),
        providerProfileDetailsProvider.overrideWith(
          (_) async => Success(profileData),
        ),
        providerEntryGateProvider.overrideWith(CompletedEntryGate.new),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        clockProvider.overrideWithValue(() => testNow),
        sessionStorageProvider.overrideWithValue(storage),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocuments()..requirementsResult = const Success([]),
        ),
        providerServiceRepositoryProvider.overrideWithValue(services),
        providerSchemaRepositoryProvider.overrideWithValue(schema),
        providerOptionsRepositoryProvider.overrideWithValue(options),
        providerCompletionRepositoryProvider.overrideWithValue(completion),
        providerProfileRepositoryProvider.overrideWithValue(
          profileRepository ?? FakeProfileRepository(),
        ),
        providerMarketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(),
        ),
        apiClientProvider.overrideWith(
          (_) => throw StateError('No live backend'),
        ),
        googleIdentityProvider.overrideWith(
          (_) => throw StateError('Google stays dormant'),
        ),
      ],
    );
    addTearDown(container.dispose);
  }
}

Future<ServiceDetailState> detail(ServiceFixture f) async =>
    (await f.container.read(
      serviceDetailControllerProvider(3).future,
    ) as Success<ServiceDetailState>).value;
Future<void> pump(
  WidgetTester tester,
  ServiceFixture f, {
  String? route = AppRoutes.services,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: f.container,
      child: const BThereProviderApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (route != null) {
    f.container.read(appRouterProvider).go(route);
    await tester.pumpAndSettle();
  }
}

String path(ServiceFixture f) =>
    f.container.read(appRouterProvider).routeInformationProvider.value.uri.path;
Map<String, dynamic> completeServiceJson({
  String verification = 'PENDING',
  String effective = 'ACTIVE',
}) {
  final j = completionJson();
  final c = j['services'][0];
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
    c[key] = true;
  }
  c['verificationStatus'] = verification;
  c['effectiveStatus'] = effective;
  return j;
}

void main() {
  for (final step in ProviderOnboardingStep.values) {
    testWidgets(
      'explicit Services link preserves service-first flow regardless of ${step.wireValue}',
      (tester) async {
        final f = ServiceFixture(step: step.wireValue);
        await pump(tester, f);
        expect(path(f), AppRoutes.services);
        expect(find.text('Services'), findsOneWidget);
        expect(find.text('Complete your profile'), findsNothing);
        f.container.read(appRouterProvider).go(AppRoutes.serviceRequirements);
        await tester.pumpAndSettle();
        expect(path(f), AppRoutes.services);
        expect(f.services.submissions, 0);
      },
    );
  }
  testWidgets(
    'completion failure does not block catalog or force global wizard',
    (tester) async {
      final f = ServiceFixture();
      f.completion.result = const Failure(
        AppFailure(message: 'Completion unavailable'),
      );
      await pump(tester, f);
      expect(path(f), AppRoutes.services);
      expect(find.text('Home Nurse'), findsOneWidget);
      expect(
        find.text('Service progress unavailable Â· Retry'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('main-service-3')));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceDetail(3));
      expect(f.services.submissions, 0);
    },
  );
  testWidgets('unauthenticated services and setup redirect to auth', (
    tester,
  ) async {
    final f = ServiceFixture(signedIn: false);
    await pump(tester, f, route: '/services/3/setup');
    expect(path(f), AppRoutes.auth);
    expect(f.services.loads, 0);
    expect(f.services.assignmentLoads, 0);
  });
  test(
    'assignment GET exact authenticated path and defensive list parsing',
    () async {
      final adapter = ProfileAdapter()..body = [assignmentJson()];
      final storage = FakeSessionStorage()..session = testSession();
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
        adapter: adapter,
      );
      addTearDown(() => client.close(force: true));
      final repo = ProviderServiceRepositoryImpl(
        ProviderServiceRemoteDataSource(client),
      );
      expect(
        await repo.loadAssignments(),
        isA<Success<List<ProviderServiceAssignment>>>(),
      );
      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/providers/me/service-types');
      expect(adapter.request!.extra['bthere.network.requires_auth'], true);
      expect(
        adapter.request!.headers['Authorization'],
        'Bearer synthetic-access',
      );
      expect(
        () => parseProviderServiceAssignments([
          assignmentJson(),
          assignmentJson(),
        ]),
        throwsFormatException,
      );
      expect(() => parseProviderServiceAssignments({}), throwsFormatException);
      expect(
        () => parseProviderServiceAssignments([
          assignmentJson()..['assignmentId'] = 0,
        ]),
        throwsFormatException,
      );
      adapter.connectionFailure = true;
      expect(
        await repo.loadAssignments(),
        isA<Failure<List<ProviderServiceAssignment>>>(),
      );
    },
  );
  testWidgets(
    'catalog opening main service only reads schema without creating assignment',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      expect(
        find.byKey(const ValueKey('service-status-available')),
        findsNWidgets(2),
      );
      await tester.tap(find.byKey(const ValueKey('main-service-3')));
      await tester.pumpAndSettle();
      expect(find.text('Sub Services'), findsOneWidget);
      expect(find.text('Work type 12'), findsOneWidget);
      expect(f.schema.calls, [3]);
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
      expect(f.storage.writes, 0);
    },
  );
  testWidgets('duplicate option names keep separate IDs and humanized codes', (
    tester,
  ) async {
    final f = ServiceFixture();
    final j = optionsSchema();
    j['options'][0]['name'] = 'Hospital Caregiver';
    j['options'][1]['name'] = 'Hospital Caregiver';
    j['options'][0]['code'] = 'HOSPITAL_DAY_CARE';
    j['options'][1]['code'] = 'HOSPITAL_NIGHT_CARE';
    f.schema.result = Success(parseProviderSchema(j, 3));
    await pump(tester, f, route: '/services/3/register');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Hospital Caregiver'), findsNWidgets(2));
    expect(find.text('Hospital Day Care'), findsOneWidget);
    expect(find.text('Hospital Night Care'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sub-service-12')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sub-service-13')));
    await tester.pump();
    expect((await detail(f)).selected, {12, 13});
  });
  for (final value in [
    '',
    'invalid',
    '-1',
    'NaN',
    'Infinity',
    '-Infinity',
    '1e9999',
  ]) {
    test('invalid experience $value blocks transaction', () async {
      final f = ServiceFixture();
      await detail(f);
      final c = f.container.read(serviceDetailControllerProvider(3).notifier);
      c.toggle(12);
      c.experience(value);
      await c.continueSetup();
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
    });
  }
  for (final value in ['0', '1', '2', '3.5', '4.5', '10000']) {
    test('main-service experience $value serialized numerically', () async {
      final f = ServiceFixture();
      await detail(f);
      final c = f.container.read(serviceDetailControllerProvider(3).notifier);
      c.toggle(12);
      c.experience(value);
      await c.continueSetup();
      expect(f.services.input!.toJson(), {
        'providerTypeId': 3,
        'experienceYears': double.parse(value),
      });
      expect(f.options.saves.single.assignmentId, 14);
      expect(f.options.saves.single.ids, [12]);
    });
  }
  test('schema selection minima maxima and null maximum respected', () {
    final s = parseProviderSchema(optionsSchema(min: 2, max: 2), 3);
    expect(validateSubServices(s, {12}), contains('at least 2'));
    expect(validateSubServices(s, {12, 13}), isNull);
    expect(validateSubServices(s, {12, 13, 14}), contains('no more than 2'));
    expect(
      validateSubServices(
        parseProviderSchema(
          optionsSchema(required: false, min: null, max: null),
          3,
        ),
        {},
      ),
      isNull,
    );
    expect(
      validateSubServices(parseProviderSchema(optionsSchema(max: null), 3), {
        12,
        13,
        14,
      }),
      isNull,
    );
  });
  test('existing assignment restores experience and selected sub-services, no POST', () async {
    final f = ServiceFixture(existing: true);
    final v = await detail(f);
    expect(v.assignment!.assignmentId, 14);
    expect(v.experience, '4.5');
    expect(v.selected, {12});
    final c = f.container.read(serviceDetailControllerProvider(3).notifier);
    c.toggle(13);
    await c.continueSetup();
    expect(f.services.submissions, 0);
    expect(f.options.saves.single.ids, [12, 13]);
  });
  test('preflight recovers assignment created since detail opened', () async {
    final f = ServiceFixture();
    await detail(f);
    f.services.assignments = Success([
      parseProviderServiceAssignment(assignmentJson()),
    ]);
    final c = f.container.read(serviceDetailControllerProvider(3).notifier);
    c.toggle(12);
    c.experience('4.5');
    await c.continueSetup();
    expect(f.services.submissions, 0);
    expect(f.options.saves.single.assignmentId, 14);
  });
  test(
    'POST succeeds PUT fails retry reuses identity and preserves draft',
    () async {
      final f = ServiceFixture();
      f.options.saveResult = const Failure(
        AppFailure(message: 'Safe save failure'),
      );
      await detail(f);
      final c = f.container.read(serviceDetailControllerProvider(3).notifier);
      c.toggle(12);
      c.toggle(13);
      c.experience('4.5');
      await c.continueSetup();
      var v = await detail(f);
      expect(v.assignment!.assignmentId, 14);
      expect(v.selected, {12, 13});
      expect(v.experience, '4.5');
      expect(v.failure!.message, 'Safe save failure');
      expect(f.services.submissions, 1);
      f.options.saveResult = const Success(null);
      await c.continueSetup();
      expect(f.services.submissions, 1);
      expect(f.options.saves.length, 2);
      expect(f.options.saves.last.assignmentId, 14);
    },
  );
  test('restart after partial success recovers backend assignment without duplicate POST', () async {
    final f = ServiceFixture();
    f.options.saveResult = const Failure(AppFailure(message: 'Try again'));
    await detail(f);
    final c = f.container.read(serviceDetailControllerProvider(3).notifier);
    c.toggle(12);
    c.experience('4.5');
    await c.continueSetup();
    f.container.invalidate(serviceDetailControllerProvider(3));
    f.container.invalidate(providerAssignmentsProvider);
    final restored = await detail(f);
    expect(restored.assignment!.assignmentId, 14);
    f.options.saveResult = const Success(null);
    final retry = f.container.read(serviceDetailControllerProvider(3).notifier);
    retry.toggle(12);
    await retry.continueSetup();
    expect(f.services.submissions, 1);
  });
  test('assignment preflight failure never falls back to POST', () async {
    final f = ServiceFixture();
    await detail(f);
    f.services.assignments = const Failure(AppFailure(message: 'Unavailable'));
    final c = f.container.read(serviceDetailControllerProvider(3).notifier);
    c.toggle(12);
    c.experience('4.5');
    await c.continueSetup();
    expect(f.services.submissions, 0);
    expect(f.options.saves, isEmpty);
    expect((await detail(f)).failure, isNotNull);
  });
  test('backend profile prerequisite failure stays in selected service without fake profile', () async {
    final f = ServiceFixture();
    f.services.submission = const Failure(
      AppFailure(
        message: 'Complete your provider profile before adding a service.',
        code: 'PROFILE_REQUIRED',
      ),
    );
    await detail(f);
    final c = f.container.read(serviceDetailControllerProvider(3).notifier);
    c.toggle(12);
    c.experience('4.5');
    await c.continueSetup();
    expect((await detail(f)).failure!.code, 'PROFILE_REQUIRED');
    expect(f.options.saves, isEmpty);
    expect(f.storage.writes, 0);
  });
  test(
    'double Continue blocked while assignment creation is pending',
    () async {
      final f = ServiceFixture();
      f.services.pendingSubmit = Completer<Result<ProviderServiceAssignment>>();
      await detail(f);
      final subscription = f.container.listen(
        serviceDetailControllerProvider(3),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final c = f.container.read(serviceDetailControllerProvider(3).notifier);
      c.toggle(12);
      c.experience('4.5');
      final save = c.continueSetup();
      await Future<void>.delayed(Duration.zero);
      await c.continueSetup();
      expect(f.services.submissions, 1);
      f.services.pendingSubmit!.complete(
        Success(parseProviderServiceAssignment(assignmentJson())),
      );
      await save;
      expect(f.options.saves.length, 1);
    },
  );
  test('setup filters dynamic fields by selected option IDs and removes options card', () async {
    final f = ServiceFixture(existing: true);
    final j = optionsSchema(fields: true)
      ..['commonFields'] = [fieldJson()..['label'] = 'Common information'];
    j['options'][1]['fields'] = [
      fieldJson(optionId: 13)..['label'] = 'Unselected field',
    ];
    j['options'][0]['fields'][0]['label'] = 'Selected field';
    f.schema.result = Success(parseProviderSchema(j, 3));
    final v = (await f.container.read(
      serviceSetupControllerProvider(3).future,
    ) as Success<ServiceSetupData>).value;
    expect(v.fields.map((f) => f.label), [
      'Common information',
      'Selected field',
    ]);
    expect(
      v.rows.map((r) => r.section),
      isNot(contains(ProviderRequirementSection.options)),
    );
    expect(
      v.rows.map((r) => r.section),
      contains(ProviderRequirementSection.additional),
    );
  });
  test(
    'setup hidden locations before saved selections and when disabled',
    () async {
      final f = ServiceFixture(existing: true);
      f.options.selections = const Success([]);
      var v = (await f.container.read(
        serviceSetupControllerProvider(3).future,
      ) as Success<ServiceSetupData>).value;
      expect(v.selectionValid, false);
      expect(
        v.rows.map((r) => r.section),
        isNot(contains(ProviderRequirementSection.locations)),
      );
    },
  );
  for (final entry in {
    'SETUP_REQUIRED': ProviderServiceStatus.setupRequired,
    'PENDING': ProviderServiceStatus.pendingApproval,
    'APPROVED': ProviderServiceStatus.approved,
    'REJECTED': ProviderServiceStatus.rejected,
    'INACTIVE': ProviderServiceStatus.inactive,
  }.entries) {
    test('product service status ${entry.key} driven by backend', () {
      final j = entry.key == 'SETUP_REQUIRED'
          ? completionJson()
          : completeServiceJson(
              verification: entry.key == 'INACTIVE' ? 'APPROVED' : entry.key,
              effective: entry.key == 'INACTIVE' ? 'INACTIVE' : 'ACTIVE',
            );
      final c = parseProviderCompletion(j).services.single;
      expect(
        productServiceStatus(
          parseProviderServiceAssignment(assignmentJson()),
          c,
        ),
        entry.value,
      );
    });
  }
  test(
    'available and unavailable progress are distinct, no invented approval',
    () {
      expect(productServiceStatus(null, null), ProviderServiceStatus.available);
      expect(productServiceStatus(null, null, progressKnown: false), isNull);
      expect(
        productServiceStatus(
          parseProviderServiceAssignment(assignmentJson()),
          null,
        ),
        isNull,
      );
    },
  );
  testWidgets('only successful sub-service save navigates to service setup', (
    tester,
  ) async {
    final f = ServiceFixture();
    (f.container.read(
      registrationDraftStoreProvider,
    ) as MemoryRegistrationDrafts).drafts[3] = readyRegistrationDraft();
    f.options.saveResult = const Failure(
      AppFailure(message: 'Safe PUT failure'),
    );
    await pump(tester, f, route: '/services/3/register');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sub-service-12')));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '4.5');
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(path(f), '/services/3/register');
    expect(find.text('Safe PUT failure'), findsOneWidget);
    expect(f.services.submissions, 1);
    f.options.saveResult = const Success(null);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(path(f), '/services/3/register');
    expect(find.text('Upload Required Documents'), findsOneWidget);
    expect(find.text('Service options'), findsNothing);
    expect(f.services.submissions, 1);
  });
  testWidgets(
    'direct setup before saved required sub-services asks for selection',
    (tester) async {
      final f = ServiceFixture(existing: true);
      f.options.selections = const Success([]);
      await pump(tester, f, route: AppRoutes.serviceSetup(3));
      expect(find.text('Choose your sub-services'), findsOneWidget);
      expect(find.text('Documents'), findsNothing);
    },
  );
  testWidgets(
    'pending approval opens status without incomplete requirement cards',
    (tester) async {
      final f = ServiceFixture(existing: true);
      f.completion.result = Success(
        parseProviderCompletion(completeServiceJson()),
      );
      await pump(tester, f, route: AppRoutes.serviceSetup(3));
      expect(path(f), AppRoutes.serviceStatus(3));
      expect(find.text('Pending approval'), findsOneWidget);
      expect(
        find.text(
          'Your information has been submitted and is waiting for review.',
        ),
        findsOneWidget,
      );
      expect(find.text('Needs attention'), findsNothing);
    },
  );
  testWidgets(
    'approved service catalog opens overview with management and read-only setup information',
    (tester) async {
      final f = ServiceFixture(existing: true);
      f.completion.result = Success(
        parseProviderCompletion(completeServiceJson(verification: 'APPROVED')),
      );
      await pump(tester, f);
      expect(
        find.byKey(const ValueKey('service-status-approved')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('main-service-3')));
      await tester.tap(find.byKey(const ValueKey('main-service-3')));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceDetail(3));
      expect(find.text('Your Registered Sub-services'), findsOneWidget);
      await tester.tap(find.text('Registered Â· Manage').first);
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceStatus(3));
      await tester.tap(find.text('View setup information'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceSetup(3));
      expect(find.text('Change services you provide'), findsNothing);
      expect(f.services.submissions, 0);
    },
  );
  testWidgets(
    'rejected service displays provided reason without invented submission endpoint',
    (tester) async {
      final f = ServiceFixture(existing: true);
      f.services.assignments = Success([
        parseProviderServiceAssignment(
          assignmentJson()
            ..['verificationStatus'] = 'REJECTED'
            ..['rejectionReason'] = 'Please provide a clearer certificate.',
        ),
      ]);
      f.completion.result = Success(
        parseProviderCompletion(completeServiceJson(verification: 'REJECTED')),
      );
      await pump(tester, f, route: AppRoutes.serviceStatus(3));
      expect(find.text('Rejected'), findsOneWidget);
      expect(
        find.text('Service review: Please provide a clearer certificate.'),
        findsOneWidget,
      );
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
    },
  );
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('service-first detail/setup responsive ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: AppRoutes.serviceDetail(3));
      expect(tester.takeException(), isNull);
      f.container.read(appRouterProvider).go(AppRoutes.serviceSetup(3));
      await tester.pumpAndSettle();
      expect(find.text('Home Nurse Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('multiple main services retain independent backend states', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    f.services.catalog = Success(
      parseActiveProviderServices([
        serviceJson(),
        serviceJson(id: 9, name: 'Tour Guide'),
        serviceJson(id: 15, name: 'Photographer'),
      ]),
    );
    f.services.assignments = Success([
      parseProviderServiceAssignment(assignmentJson()),
      parseProviderServiceAssignment(
        assignmentJson(typeId: 9)
          ..['assignmentId'] = 28
          ..['verificationStatus'] = 'APPROVED',
      ),
    ]);
    final j = completionJson();
    final guide =
        Map<String, dynamic>.from(
            completeServiceJson(verification: 'APPROVED')['services'][0],
          )
          ..['assignmentId'] = 28
          ..['serviceTypeId'] = 9
          ..['serviceName'] = 'Tour Guide';
    j['services'] = [j['services'][0], guide];
    f.completion.result = Success(parseProviderCompletion(j));
    await pump(tester, f);
    expect(
      find.byKey(const ValueKey('service-status-setupRequired')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('service-status-approved')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('service-status-available')),
      findsOneWidget,
    );
    expect(f.services.submissions, 0);
  });
  testWidgets(
    'identical names and codes keep distinct variants and expose catalog concern',
    (tester) async {
      final f = ServiceFixture();
      final j = optionsSchema();
      j['options'][0]['name'] = 'Hospital Caregiver';
      j['options'][1]['name'] = 'Hospital Caregiver';
      j['options'][0]['code'] = 'HOSPITAL_CARE';
      j['options'][1]['code'] = 'HOSPITAL_CARE';
      f.schema.result = Success(parseProviderSchema(j, 3));
      await pump(tester, f, route: '/services/3/register');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Hospital Caregiver'), findsNWidgets(2));
      expect(find.text('Variant 12'), findsOneWidget);
      expect(find.text('Variant 13'), findsOneWidget);
      expect(f.options.saves, isEmpty);
    },
  );
  testWidgets(
    'only selected option fields displayed in Additional information',
    (tester) async {
      final f = ServiceFixture(existing: true);
      final j = optionsSchema(fields: true)
        ..['commonFields'] = [fieldJson()..['label'] = 'Common information'];
      j['options'][0]['fields'][0]['label'] = 'Selected information';
      j['options'][1]['fields'] = [
        fieldJson(optionId: 13)..['label'] = 'Hidden information',
      ];
      f.schema.result = Success(parseProviderSchema(j, 3));
      await pump(tester, f, route: '/services/3/setup/additional');
      expect(find.text('Common information *'), findsOneWidget);
      await tester.ensureVisible(find.text('Work type 12'));
      await tester.tap(find.text('Work type 12'));
      await tester.pumpAndSettle();
      expect(find.text('Selected information *'), findsOneWidget);
      expect(find.text('Hidden information'), findsNothing);
      expect(f.options.saves, isEmpty);
    },
  );
  testWidgets(
    'documents stay service-specific and absent when schema has none',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f);
      expect(find.text('Documents'), findsNothing);
      f.container.read(appRouterProvider).go('/services/3/setup/documents');
      await tester.pumpAndSettle();
      expect(find.text('Upload Required Documents'), findsOneWidget);
      expect(
        find.text('No documents are required for this service.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'catalog load failure and empty state allow retry without writes',
    (tester) async {
      final f = ServiceFixture();
      f.services.catalog = const Failure(AppFailure(message: 'Unavailable'));
      await pump(tester, f);
      expect(find.text('Retry'), findsOneWidget);
      f.services.catalog = const Success([]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No services are available right now.'), findsOneWidget);
      expect(f.services.submissions, 0);
    },
  );
  testWidgets(
    'schema failure retries service reads without creating assignment',
    (tester) async {
      final f = ServiceFixture();
      f.schema.result = const Failure(AppFailure(message: 'Unavailable'));
      await pump(tester, f, route: AppRoutes.serviceDetail(3));
      expect(find.text('Retry'), findsOneWidget);
      f.schema.result = Success(parseProviderSchema(optionsSchema(), 3));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Work type 12'), findsOneWidget);
      expect(f.services.submissions, 0);
    },
  );
  test('optional and disabled false flags do not force pending service through setup', () async {
    final f = ServiceFixture(existing: true);
    final j = completeServiceJson();
    j['services'][0]['certificatesCompleted'] = false;
    j['services'][0]['educationCompleted'] = false;
    j['services'][0]['documentsCompleted'] = false;
    j['services'][0]['skillsCompleted'] = false;
    f.completion.result = Success(parseProviderCompletion(j));
    final schema = optionsSchema();
    schema['serviceSetup']['certificates']['level'] = 'OPTIONAL';
    schema['serviceSetup']['education']['level'] = 'DISABLED';
    f.schema.result = Success(parseProviderSchema(schema, 3));
    final value = (await f.container.read(
      serviceSetupControllerProvider(3).future,
    ) as Success<ServiceSetupData>).value;
    expect(value.status, ProviderServiceStatus.pendingApproval);
  });
  testWidgets('inactive service shows status without restarting setup', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    f.services.assignments = Success([
      parseProviderServiceAssignment(
        assignmentJson()..['providerStatus'] = 'INACTIVE',
      ),
    ]);
    await pump(tester, f, route: AppRoutes.serviceStatus(3));
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Change services you provide'), findsNothing);
  });
  for (final type in [
    'TEXT',
    'TEXTAREA',
    'NUMBER',
    'BOOLEAN',
    'DATE',
    'TIME',
    'PHONE',
    'EMAIL',
    'SELECT',
    'MULTI_SELECT',
    'IMAGE_UPLOAD',
    'DOCUMENT_UPLOAD',
    'FILE_UPLOAD',
  ]) {
    test(
      'dynamic $type metadata supported without creating submission forms',
      () {
        final j = optionsSchema()
          ..['commonFields'] = [fieldJson()..['fieldType'] = type];
        expect(parseProviderSchema(j, 3).commonFields.single.fieldType, type);
      },
    );
  }
  testWidgets(
    'Basic details is not exposed before assignment and saved sub-services',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f, route: '/services/3/setup/profile');
      expect(find.text('First name'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(f.services.submissions, 0);
    },
  );
  testWidgets(
    'service setup Basic details preserves profile and market form without identity documents',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: '/services/3/setup/profile');
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('NIC number'), findsNothing);
      expect(find.text('Passport number'), findsNothing);
      await tester.ensureVisible(find.text('Back to setup'));
      await tester.tap(find.text('Back to setup'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceSetup(3));
    },
  );
  testWidgets('direct approved service detail shows registered overview', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    f.completion.result = Success(
      parseProviderCompletion(completeServiceJson(verification: 'APPROVED')),
    );
    await pump(tester, f, route: AppRoutes.serviceDetail(3));
    expect(path(f), AppRoutes.serviceDetail(3));
    expect(find.text('Your Registered Sub-services'), findsOneWidget);
    expect(find.text('Years of experience'), findsNothing);
    expect(f.services.submissions, 0);
  });
  testWidgets(
    'successful Basic details returns to the same service setup and refreshes completion',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: '/services/3/setup/profile');
      await f.container.read(providerMarketControllerProvider.future);
      await f.container
          .read(providerProfileControllerProvider.notifier)
          .submit(input());
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceSetup(3));
      expect(f.completion.calls, 2);
      expect(find.text('Home Nurse Setup'), findsOneWidget);
    },
  );
}
