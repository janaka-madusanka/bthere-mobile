import 'support/completed_entry_gate.dart';

import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';

import 'support/fake_configured_service.dart';
import 'support/fake_market_repository.dart';

import 'package:provider_app/features/onboarding/markets/application/provider_market_controller.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/application/provider_completion_controller.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/profile/application/provider_profile_controller.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_remote_data_source.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_repository_impl.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_request.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';

import 'support/fake_completion_repository.dart';
import 'support/fake_profile_repository.dart';
import 'support/fake_session_storage.dart';

ProviderProfileInput input({
  int marketId = 7,
  String first = ' Jane ',
  String last = ' Doe ',
  String? bio,
  DateTime? date,
  ProviderAvailability availability = ProviderAvailability.available,
  ProviderGender gender = ProviderGender.male,
}) => ProviderProfileInput(
  marketId: marketId,
  firstName: first,
  lastName: last,
  dateOfBirth: date ?? DateTime(1990, 2, 3),
  gender: gender,
  availabilityStatus: availability,
  bio: bio,
);

final class ProfileAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body = {'ignored': 'undocumented success body'};
  RequestOptions? request;
  bool connectionFailure = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (connectionFailure) {
      throw StateError('synthetic private transport failure');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('exact profile serialization includes ten keys, trimmed text, null photo and selected market ID', () {
    expect(serializeProviderProfile(input(bio: ' Hello\nworld ')), {
      'firstName': 'Jane',
      'lastName': 'Doe',
      'nicNumber': null,
      'passportNumber': null,
      'dateOfBirth': '1990-02-03',
      'gender': 'MALE',
      'profilePhoto': null,
      'bio': 'Hello\nworld',
      'availabilityStatus': 'AVAILABLE',
      'marketId': 7,
    });
    expect(serializeProviderProfile(input(marketId: 42))['marketId'], 42);
    expect(input().profilePhoto, isNull);
  });
  for (final field in ['nicNumber', 'passportNumber', 'bio']) {
    test(
      field == 'bio'
          ? 'empty and whitespace bio serialize as null'
          : '$field always serializes as null regardless of bio',
      () {
        for (final value in [null, '', '   ']) {
          final serialized = serializeProviderProfile(input(bio: value));
          expect(serialized[field], isNull);
        }
      },
    );
  }
  test('dates use calendar components, padded YYYY-MM-DD, without timezone conversion', () {
    expect(
      serializeProviderProfile(
        input(date: DateTime.utc(2000, 2, 29, 23)),
      )['dateOfBirth'],
      '2000-02-29',
    );
    expect(
      serializeProviderProfile(input(date: DateTime(1, 1, 2)))['dateOfBirth'],
      '0001-01-02',
    );
  });
  for (final availability in ProviderAvailability.values) {
    test('availability serializes exact ${availability.wireValue}', () {
      expect(
        serializeProviderProfile(
          input(availability: availability),
        )['availabilityStatus'],
        availability.wireValue,
      );
    });
  }
  test('exactly the two confirmed gender wire values are offered', () {
    expect(ProviderGender.values.map((value) => value.wireValue), [
      'MALE',
      'FEMALE',
    ]);
  });
  test('basic domain validation does not impose age or bio limits', () {
    expect(input(date: testNow).validationMessage(testNow), isNull);
    expect(
      input(date: DateTime(1), bio: 'x' * 10000).validationMessage(testNow),
      isNull,
    );
    expect(input(first: '  ').validationMessage(testNow), isNotNull);
    expect(input(last: '').validationMessage(testNow), isNotNull);
    expect(
      input(date: testNow.add(const Duration(days: 1)))
          .validationMessage(testNow),
      isNotNull,
    );
    expect(input().validationMessage(testNow), isNull);
  });

  late ProfileAdapter adapter;
  late ApiClient client;
  late FakeSessionStorage storage;
  late ProviderProfileRepositoryImpl repository;
  setUp(() {
    adapter = ProfileAdapter();
    storage = FakeSessionStorage()..session = testSession();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
      adapter: adapter,
    );
    repository = ProviderProfileRepositoryImpl(
      ProviderProfileRemoteDataSource(client),
    );
  });
  tearDown(() => client.close(force: true));
  test(
    'error inspection receives status/body without changing normalized failure',
    () async {
      adapter.status = 500;
      adapter.body = {
        'title': 'Internal server error',
        'detail': 'private detail',
      };
      Object? observed;
      int? status;
      await expectLater(
        client.put<Object?>(
          '/providers/me/profile',
          requiresAuth: true,
          data: serializeProviderProfile(input()),
          onErrorResponse: (response) {
            observed = response?.data;
            status = response?.statusCode;
            throw StateError('diagnostic sink failed');
          },
        ),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'unchanged fallback',
            'The server could not complete the request.',
          ),
        ),
      );
      expect(status, 500);
      expect(observed, adapter.body);
    },
  );

  test(
    'PUT profile uses requiresAuth and token bridge with exact body',
    () async {
      expect(await repository.updateProfile(input()), isA<Success<void>>());
      final request = adapter.request!;
      expect(request.method, 'PUT');
      expect(request.path, '/providers/me/profile');
      expect(request.extra['bthere.network.requires_auth'], isTrue);
      expect(request.headers['Authorization'], 'Bearer synthetic-access');
      expect(request.data, {
        'firstName': 'Jane',
        'lastName': 'Doe',
        'nicNumber': null,
        'passportNumber': null,
        'dateOfBirth': '1990-02-03',
        'gender': 'MALE',
        'profilePhoto': null,
        'bio': null,
        'availabilityStatus': 'AVAILABLE',
        'marketId': 7,
      });
      expect(storage.writes, 0);
      expect(storage.clears, 0);
    },
  );
  for (final status in [200, 201, 204]) {
    test(
      'HTTP $status success does not require an invented response DTO',
      () async {
        adapter.status = status;
        adapter.body = null;
        expect(await repository.updateProfile(input()), isA<Success<void>>());
      },
    );
  }
  for (final status in [400, 401, 403, 500]) {
    test(
      'HTTP $status failure stays safe and does not modify credentials',
      () async {
        adapter.status = status;
        adapter.body = {
          'message': 'private backend token stack',
          'errors': {'marketId': 'private required'},
        };
        final result = await repository.updateProfile(input()) as Failure<void>;
        expect(result.failure.message, isNot(contains('private')));
        expect(result.failure.cause, isNull);
        expect(storage.clears, 0);
        expect(storage.writes, 0);
      },
    );
  }
  test(
    'validation failure maps readable safe guidance without raw backend fields',
    () async {
      adapter.status = 400;
      adapter.body = {
        'message': 'Validation failed',
        'code': 'VALIDATION_ERROR',
        'errors': {'firstName': 'private info'},
      };
      final result = await repository.updateProfile(input()) as Failure<void>;
      expect(result.failure.code, 'VALIDATION_ERROR');
      expect(
        result.failure.message,
        'Please check your profile details and try again.',
      );
      expect(result.failure.cause, isNull);
    },
  );
  test(
    'transport failure maps through common failure infrastructure',
    () async {
      adapter.connectionFailure = true;
      final result = await repository.updateProfile(input()) as Failure<void>;
      expect(result.failure.code, startsWith('NETWORK_'));
      expect(result.failure.message, isNot(contains('private')));
    },
  );

  late FakeProfileRepository profile;
  late FakeCompletionRepository completion;
  late ProviderContainer container;
  Future<void> setupControllers() async {
    profile = FakeProfileRepository();
    completion = FakeCompletionRepository()
      ..result = Success(
        parseProviderCompletion(completionJson(step: 'COMPLETE_PROFILE')),
      );
    container = ProviderContainer(
      overrides: [
        providerEntryGateProvider.overrideWith(CompletedEntryGate.new),
        providerServiceRepositoryProvider.overrideWithValue(
          configuredServiceRepository(),
        ),
        providerSchemaRepositoryProvider.overrideWithValue(
          configuredSchemaRepository(),
        ),
        providerOptionsRepositoryProvider.overrideWithValue(
          configuredOptionsRepository(),
        ),
        providerMarketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage()..session = testSession(),
        ),
        clockProvider.overrideWithValue(() => testNow),
        providerProfileRepositoryProvider.overrideWithValue(profile),
        providerCompletionRepositoryProvider.overrideWithValue(completion),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No live requests'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(providerProfileControllerProvider, (_, _) {});
    container.listen(providerCompletionControllerProvider, (_, _) {});
    container.listen(providerMarketControllerProvider, (_, _) {});
    await container.read(providerMarketControllerProvider.future);
    await container.read(providerCompletionControllerProvider.future);
  }

  test(
    'valid submit reloads completion only after acknowledged profile success',
    () async {
      await setupControllers();
      profile.pending = Completer<Result<void>>();
      final work = container
          .read(providerProfileControllerProvider.notifier)
          .submit(input());
      expect(container.read(providerProfileControllerProvider).loading, isTrue);
      expect(completion.calls, 1);
      profile.pending!.complete(const Success(null));
      await work;
      await container.read(providerCompletionControllerProvider.future);
      expect(profile.calls, 1);
      expect(completion.calls, 2);
      expect(profile.input!.firstName, ' Jane ');
      expect(container.read(providerProfileControllerProvider).saved, isTrue);
      await container
          .read(providerProfileControllerProvider.notifier)
          .submit(input());
      expect(profile.calls, 1);
    },
  );
  test('controller blocks duplicate submissions during request', () async {
    await setupControllers();
    profile.pending = Completer<Result<void>>();
    final controller = container.read(
      providerProfileControllerProvider.notifier,
    );
    final work = controller.submit(input());
    await controller.submit(input());
    expect(profile.calls, 1);
    profile.pending!.complete(const Failure(AppFailure(message: 'Try again')));
    await work;
    expect(container.read(providerProfileControllerProvider).loading, isFalse);
  });
  for (final invalid in [
    input(first: ''),
    input(last: ' '),
    input(date: DateTime(2031)),
  ]) {
    test(
      'invalid profile is rejected by controller before transport: ${invalid.validationMessage(testNow)}',
      () async {
        await setupControllers();
        await container
            .read(providerProfileControllerProvider.notifier)
            .submit(invalid);
        expect(profile.calls, 0);
        expect(
          container.read(providerProfileControllerProvider).failure!.code,
          'PROFILE_VALIDATION_FAILED',
        );
        expect(completion.calls, 1);
      },
    );
  }
  test('safe failure allows retry and does not refresh completion', () async {
    await setupControllers();
    profile.result = const Failure(
      AppFailure(
        message: 'Unable to connect.',
        code: 'NETWORK_CONNECTION',
        cause: 'private',
      ),
    );
    final controller = container.read(
      providerProfileControllerProvider.notifier,
    );
    await controller.submit(input());
    expect(
      container.read(providerProfileControllerProvider).failure!.cause,
      isNull,
    );
    expect(completion.calls, 1);
    profile.result = const Success(null);
    await controller.submit(input());
    await container.read(providerCompletionControllerProvider.future);
    expect(profile.calls, 2);
    expect(completion.calls, 2);
  });
  test(
    'unexpected exceptions are safe failures and do not reload completion',
    () async {
      await setupControllers();
      profile.throwOnUpdate = true;
      await container
          .read(providerProfileControllerProvider.notifier)
          .submit(input());
      expect(
        container.read(providerProfileControllerProvider).failure!.message,
        isNot(contains('private')),
      );
      expect(completion.calls, 1);
    },
  );
  test('disposed controller does not trigger completion refresh after late success', () async {
    await setupControllers();
    profile.pending = Completer<Result<void>>();
    final work = container
        .read(providerProfileControllerProvider.notifier)
        .submit(input());
    container.dispose();
    profile.pending!.complete(const Success(null));
    await work;
    expect(completion.calls, 1);
  });

  Finder field(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is BThereTextField && widget.label == label,
    ),
    matching: find.byType(TextFormField),
  );
  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    FakeProfileRepository? repo,
    FakeCompletionRepository? gateway,
  }) async {
    final scope = ProviderContainer(
      overrides: [
        providerEntryGateProvider.overrideWith(CompletedEntryGate.new),
        providerServiceRepositoryProvider.overrideWithValue(
          configuredServiceRepository(),
        ),
        providerSchemaRepositoryProvider.overrideWithValue(
          configuredSchemaRepository(),
        ),
        providerOptionsRepositoryProvider.overrideWithValue(
          configuredOptionsRepository(),
        ),
        providerMarketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage()..session = testSession(),
        ),
        clockProvider.overrideWithValue(() => testNow),
        providerProfileRepositoryProvider.overrideWithValue(
          repo ?? FakeProfileRepository(),
        ),
        providerCompletionRepositoryProvider.overrideWithValue(
          gateway ??
              (FakeCompletionRepository()
                ..result = Success(
                  parseProviderCompletion(
                    completionJson(step: 'COMPLETE_PROFILE'),
                  ),
                )),
        ),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No live backend'),
        ),
        googleIdentityProvider.overrideWith(
          (ref) => throw StateError('Google dormant'),
        ),
      ],
    );
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: const BThereProviderApp(),
      ),
    );
    await tester.pumpAndSettle();
    scope.read(appRouterProvider).go('/services/3/setup/profile');
    await tester.pumpAndSettle();
    return scope;
  }

  Future<void> pickDate(WidgetTester tester) async {
    final dateField = find.byKey(const ValueKey('profile-date-of-birth'));
    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> selectMarket(WidgetTester tester) async {
    final selector = find.byKey(const ValueKey('profile-market'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test market').last);
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(field('First name'), ' Jane ');
    await tester.enterText(field('Last name'), ' Doe ');
    await pickDate(tester);
    final gender = find.byKey(const ValueKey('profile-gender'));
    await tester.ensureVisible(gender);
    await tester.tap(gender);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await selectMarket(tester);
  }

  Future<void> pressContinue(WidgetTester tester) async {
    final button = find.widgetWithText(BThereButton, 'Continue');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets(
    'required and optional fields, real multiline bio, required market and no photo controls',
    (tester) async {
      await pumpProfile(tester);
      for (final label in [
        'First name',
        'Last name',
        'Date of birth',
        'Gender',
        'Market',
        'Availability status',
        'Bio (optional)',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      final bio = tester.widget<TextField>(
        find.descendant(
          of: field('Bio (optional)'),
          matching: find.byType(TextField),
        ),
      );
      expect(bio.minLines, 3);
      expect(bio.maxLines, 5);
      expect(find.byKey(const ValueKey('profile-market')), findsOneWidget);
      expect(find.textContaining('NIC'), findsNothing);
      expect(find.textContaining('Passport'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.textContaining('Upload'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.widgetWithText(BThereButton, 'Continue'), findsOneWidget);
    },
  );
  testWidgets('required validation blocks network submission', (tester) async {
    final repo = FakeProfileRepository();
    await pumpProfile(tester, repo: repo);
    await selectMarket(tester);
    await pressContinue(tester);
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsNWidgets(2));
    expect(find.text('Select your date of birth.'), findsOneWidget);
    expect(find.text('Select your gender.'), findsOneWidget);
    expect(repo.calls, 0);
  });
  testWidgets(
    'calendar-only date picker disallows future dates and manual editing',
    (tester) async {
      await pumpProfile(tester);
      final target = find.byKey(const ValueKey('profile-date-of-birth'));
      final date = tester.widget<TextField>(
        find.descendant(of: target, matching: find.byType(TextField)),
      );
      expect(date.readOnly, isTrue);
      expect(date.enableInteractiveSelection, isFalse);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateTime(2030, 1, 2));
      expect(picker.firstDate, DateTime(1));
      expect(picker.initialEntryMode, DatePickerEntryMode.calendarOnly);
      expect(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(target).controller!.text,
        'Jan 2, 2030',
      );
    },
  );
  testWidgets('canceled date picker leaves date unset', (tester) async {
    await pumpProfile(tester);
    final target = find.byKey(const ValueKey('profile-date-of-birth'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(target).controller!.text, isEmpty);
  });
  testWidgets('availability defaults Available and offers documented choices', (
    tester,
  ) async {
    final repo = FakeProfileRepository()
      ..result = const Failure(AppFailure(message: 'Synthetic failure'));
    await pumpProfile(tester, repo: repo);
    expect(
      tester
          .widget<DropdownButtonFormField<ProviderAvailability>>(
            find.byKey(const ValueKey('profile-availability')),
          )
          .initialValue,
      ProviderAvailability.available,
    );
    await fillForm(tester);
    final selector = find.byKey(const ValueKey('profile-availability'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsWidgets);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('Offline'), findsWidgets);
    await tester.tap(find.text('Offline').last);
    await tester.pumpAndSettle();
    await pressContinue(tester);
    await tester.pumpAndSettle();
    expect(repo.input!.availabilityStatus, ProviderAvailability.offline);
  });
  testWidgets(
    'pending submission disables fields and CTA; failure preserves values for retry',
    (tester) async {
      final repo = FakeProfileRepository()..pending = Completer<Result<void>>();
      final gateway = FakeCompletionRepository()
        ..result = Success(
          parseProviderCompletion(completionJson(step: 'COMPLETE_PROFILE')),
        );
      final scope = await pumpProfile(tester, repo: repo, gateway: gateway);
      await fillForm(tester);
      await tester.enterText(field('Bio (optional)'), 'My bio\nMore details');
      await pressContinue(tester);
      final button = tester.widget<BThereButton>(
        find.widgetWithText(BThereButton, 'Continue'),
      );
      expect(button.loading, isTrue);
      expect(button.onPressed, isNull);
      for (final label in ['First name', 'Last name', 'Bio (optional)']) {
        expect(tester.widget<TextFormField>(field(label)).enabled, isFalse);
      }
      expect(
        tester
            .widget<BThereSelectorField<ProviderGender>>(
              find.byKey(const ValueKey('profile-gender')),
            )
            .onChanged,
        isNull,
      );
      expect(
        scope.read(appRouterProvider).routeInformationProvider.value.uri.path,
        '/services/3/setup/profile',
      );
      expect(gateway.calls, 1);
      repo.pending!.complete(
        const Failure(AppFailure(message: 'Unable to connect.')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to connect.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('First name')).controller!.text,
        ' Jane ',
      );
      expect(
        tester.widget<TextFormField>(field('Last name')).controller!.text,
        ' Doe ',
      );
      expect(
        tester.widget<TextFormField>(field('Bio (optional)')).controller!.text,
        'My bio\nMore details',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('profile-date-of-birth')),
            )
            .controller!
            .text,
        isNotEmpty,
      );
      expect(
        tester
            .widget<BThereButton>(find.widgetWithText(BThereButton, 'Continue'))
            .loading,
        isFalse,
      );
      repo.pending = null;
      repo.result = const Failure(AppFailure(message: 'Try again'));
      await pressContinue(tester);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(gateway.calls, 1);
    },
  );
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'profile form is scrollable and keyboard safe with narrow large text ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await pumpProfile(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        final button = find.widgetWithText(BThereButton, 'Continue');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(button.hitTestable(), findsOneWidget);
        expect(Theme.of(tester.element(button)).brightness, brightness);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
