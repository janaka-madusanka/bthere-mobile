import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_common/bthere_common.dart';
import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:bthere_design_system/bthere_design_system.dart';
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
import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';
import 'package:provider_app/features/onboarding/profile/application/provider_profile_controller.dart';

import 'email_auth_screen_test.dart' as auth_ui;
import 'support/fake_completion_repository.dart';
import 'support/fake_market_repository.dart';
import 'support/fake_service_repository.dart';
import 'support/fake_session_storage.dart';

/// Exercises real repositories with local HTTP responses, never live accounts.
class OnboardingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> completion = completionJson();
  int completionStatus = 200, profileStatus = 200, marketStatus = 200;
  String? completionTransportFailure;
  Object? completionBody;
  List<Object?> markets = [marketJson(id: 42, name: 'API market')];
  Completer<void>? pendingProfile, pendingCompletion, pendingMarket;
  final user = <String, Object?>{
    'id': 25,
    'username': 'provider',
    'email': 'provider@example.com',
    'status': 'ACTIVE',
    'roles': ['SERVICE_PROVIDER'],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object? body;
    int status = 200;
    switch (options.path) {
      case '/auth/register':
        status = 201;
        body = {
          ...user,
          'status': 'PENDING',
          'emailVerified': false,
          'phoneVerified': false,
          'phoneNumber': null,
        };
      case '/auth/email/verify':
      case '/auth/login':
        body = {
          'accessToken': 'synthetic-access',
          'refreshToken': 'synthetic-refresh',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'user': user,
        };
      case '/providers/me/completion':
        await pendingCompletion?.future;
        if (completionTransportFailure != null) {
          throw DioException(
            requestOptions: options,
            type: completionTransportFailure == 'timeout'
                ? DioExceptionType.connectionTimeout
                : DioExceptionType.connectionError,
          );
        }
        status = completionStatus;
        body =
            completionBody ??
            (status == 200
                ? completion
                : {'message': 'synthetic private server details'});
      case '/markets':
        await pendingMarket?.future;
        status = marketStatus;
        body = status == 200 ? markets : {'message': 'private market failure'};
      case '/providers/me/profile':
        await pendingProfile?.future;
        status = profileStatus;
        body = status == 200
            ? {'profileCompleted': true, 'marketId': 42}
            : {
                'message': 'Validation failed',
                'errors': {'firstName': 'private'},
              };
        if (status == 200) completion = completionJson(step: 'SELECT_SERVICE');
      default:
        throw StateError('Unexpected endpoint: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  List<RequestOptions> matching(String path) =>
      requests.where((r) => r.path == path).toList();
  @override
  void close({bool force = false}) {}
}

class OnboardingFixture {
  final adapter = OnboardingAdapter();
  final storage = FakeSessionStorage();
  late final ApiClient client = ApiClient(
    config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
    tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
    adapter: adapter,
  );
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
      ),
      clockProvider.overrideWithValue(() => testNow),
      sessionStorageProvider.overrideWithValue(storage),
      apiClientProvider.overrideWithValue(client),
      providerServiceRepositoryProvider.overrideWithValue(
        FakeServiceRepository(),
      ),
      googleIdentityProvider.overrideWith(
        (_) => throw StateError('Google stays dormant'),
      ),
    ],
  );
  String get path =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BThereProviderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    container.dispose();
    client.close(force: true);
  }
}

Future<void> select(WidgetTester tester, String key, String label) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> fillProfile(WidgetTester tester) async {
  await tester.enterText(auth_ui.field('First name'), ' Jane ');
  await tester.enterText(auth_ui.field('Last name'), ' Doe ');
  final date = find.byKey(const ValueKey('profile-date-of-birth'));
  await tester.ensureVisible(date);
  await tester.tap(date);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await select(tester, 'profile-gender', 'Male');
  await select(tester, 'profile-market', 'API market');
}

Future<void> saveProfile(WidgetTester tester) async {
  final button = find.widgetWithText(BThereButton, 'Save profile');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  late OnboardingFixture f;
  setUp(() => f = OnboardingFixture());
  tearDown(() => f.dispose());

  testWidgets(
    'real registration to verification to details to services and restore uses exact contracts',
    (tester) async {
      await f.pump(tester);
      await auth_ui.openRegistration(tester);
      await auth_ui.fillRegistration(
        tester,
        email: ' provider@example.com ',
        password: ' password 10 ',
      );
      await auth_ui.pressCreate(tester);
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.emailVerification);
      expect(f.storage.session, isNull);
      expect(f.storage.writes, 0);
      expect(f.adapter.matching('/auth/register').single.data, {
        'email': 'provider@example.com',
        'password': ' password 10 ',
        'accountType': 'SERVICE_PROVIDER',
      });
      expect(find.text('provider@example.com'), findsOneWidget);
      await tester.enterText(auth_ui.field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.profile);
      expect(find.text('Provider Details'), findsOneWidget);
      expect(find.text('Services'), findsNothing);
      expect(f.storage.writes, 1);
      expect(f.storage.session!.accessToken, 'synthetic-access');
      expect(f.storage.session!.refreshToken, 'synthetic-refresh');
      expect(f.storage.session!.user!.id, 25);
      expect(f.storage.session!.user!.roles, ['SERVICE_PROVIDER']);
      expect(
        f.storage.session!.expiresAt,
        testNow.add(const Duration(seconds: 900)),
      );
      expect(f.adapter.matching('/auth/email/verify').single.data, {
        'email': 'provider@example.com',
        'otp': '123456',
      });
      expect(find.byKey(const ValueKey('profile-availability')), findsNothing);
      expect(f.adapter.matching('/providers/me/completion'), isEmpty);
      await fillProfile(tester);
      await saveProfile(tester);
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.home);
      final put = f.adapter.matching('/providers/me/profile').single;
      expect(put.method, 'PUT');
      expect(put.data, {
        'firstName': 'Jane',
        'lastName': 'Doe',
        'nicNumber': null,
        'passportNumber': null,
        'dateOfBirth': '2030-01-02',
        'gender': 'MALE',
        'profilePhoto': null,
        'bio': null,
        'availabilityStatus': 'AVAILABLE',
        'marketId': 42,
      });
      for (final request in f.adapter.requests) {
        expect(request.uri.path, '/api/v1${request.path}');
        final public = request.path.startsWith('/auth/');
        expect(request.extra['bthere.network.requires_auth'], !public);
        expect(
          request.headers['Authorization'],
          public ? isNull : 'Bearer synthetic-access',
        );
      }
      f.container.read(appRouterProvider).go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.home);
      expect(f.container.read(appRouterProvider).canPop(), isFalse);
      // New app container with the same secure session represents kill/reopen.
      await tester.pumpWidget(const SizedBox());
      f.container.dispose();
      final restarted = OnboardingFixture();
      addTearDown(restarted.dispose);
      restarted.storage.session = f.storage.session;
      await restarted.pump(tester);
      expect(restarted.path, AppRoutes.home);
      expect(restarted.adapter.matching('/providers/me/completion').length, 1);
      expect(restarted.adapter.matching('/providers/me/profile'), isEmpty);
    },
  );

  testWidgets(
    'verified but unfinished account reopens in details without another registration',
    (tester) async {
      await f.pump(tester);
      await auth_ui.openRegistration(tester);
      await auth_ui.fillRegistration(tester);
      await auth_ui.pressCreate(tester);
      await tester.pumpAndSettle();
      await tester.enterText(auth_ui.field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.profile);
      await tester.pumpWidget(const SizedBox());
      f.container.dispose();
      final restarted = OnboardingFixture();
      addTearDown(restarted.dispose);
      restarted.storage.session = f.storage.session;
      restarted.adapter.completion = completionJson(step: 'COMPLETE_PROFILE')
        ..['profileCompleted'] = false
        ..['marketSelected'] = false;
      await restarted.pump(tester);
      expect(restarted.path, AppRoutes.profile);
      expect(restarted.adapter.matching('/auth/register'), isEmpty);
      expect(restarted.storage.writes, 0);
      expect(find.text('Provider Details'), findsOneWidget);
    },
  );

  testWidgets('account check shows loading and retry requests coalesce', (
    tester,
  ) async {
    f.storage.session = testSession();
    f.adapter.pendingCompletion = Completer<void>();
    f.adapter.completionStatus = 500;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: const BThereProviderApp(),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f.path, AppRoutes.startup);
    expect(find.byType(BThereLoadingIndicator), findsOneWidget);
    expect(f.adapter.matching('/providers/me/completion').length, 1);
    expect(f.adapter.matching('/markets'), isEmpty);
    f.adapter.pendingCompletion!.complete();
    await tester.pumpAndSettle();
    f.adapter.completionStatus = 200;
    f.adapter.pendingCompletion = Completer<void>();
    final gate = f.container.read(providerEntryGateProvider.notifier);
    gate.retry();
    gate.retry();
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f.adapter.matching('/providers/me/completion').length, 2);
    f.adapter.pendingCompletion!.complete();
    await tester.pumpAndSettle();
    expect(f.path, AppRoutes.home);
  });

  testWidgets(
    'incomplete service flags do not turn entry gate into the retired wizard',
    (tester) async {
      f.storage.session = testSession();
      f.adapter.completion = completionJson(step: 'SELECT_SERVICE')
        ..['serviceSelected'] = false
        ..['services'] = [];
      await f.pump(tester);
      expect(f.path, AppRoutes.home);
      expect(f.adapter.matching('/markets'), isEmpty);
    },
  );

  for (final step in [
    'SELECT_SERVICE',
    'COMPLETE_SERVICE_REQUIREMENTS',
    'AWAIT_ADMIN_APPROVAL',
    'COMPLETED',
  ]) {
    testWidgets('restored profile and market complete with $step enters Home', (
      tester,
    ) async {
      f.storage.session = testSession();
      f.adapter.completion = completionJson(step: step);
      await f.pump(tester);
      expect(f.path, AppRoutes.home);
      expect(f.adapter.matching('/providers/me/completion').length, 1);
    });
  }
  for (final variant in [
    'profile false',
    'market false',
    'COMPLETE_PROFILE',
    'SELECT_MARKET',
  ]) {
    testWidgets(
      'restored authenticated $variant enters details and blocks services/auth',
      (tester) async {
        f.storage.session = testSession();
        if (variant == 'profile false') {
          f.adapter.completion['profileCompleted'] = false;
        }
        if (variant == 'market false') {
          f.adapter.completion['marketSelected'] = false;
        }
        if (variant == 'COMPLETE_PROFILE' || variant == 'SELECT_MARKET') {
          f.adapter.completion['nextStep'] = variant;
        }
        await f.pump(tester);
        expect(f.path, AppRoutes.profile);
        for (final path in [
          AppRoutes.home,
          AppRoutes.services,
          '/services/3/setup/documents',
          AppRoutes.emailRegistration,
          AppRoutes.auth,
        ]) {
          f.container.read(appRouterProvider).go(path);
          await tester.pumpAndSettle();
          expect(f.path, AppRoutes.profile);
        }
        expect(f.storage.clears, 0);
      },
    );
  }
  for (final failure in [
    '401',
    '404',
    '500',
    'offline',
    'timeout',
    'malformed',
  ]) {
    testWidgets(
      'completion $failure remains an error, retry recovers without missing-profile inference',
      (tester) async {
        f.storage.session = testSession();
        final status = int.tryParse(failure);
        if (status != null) f.adapter.completionStatus = status;
        if (failure == 'offline' || failure == 'timeout') {
          f.adapter.completionTransportFailure = failure;
        }
        if (failure == 'malformed') {
          f.adapter.completionBody = {'profileCompleted': false};
        }
        await f.pump(tester);
        expect(f.path, AppRoutes.startup);
        expect(find.text('Provider Details'), findsNothing);
        expect(find.text('Retry account setup'), findsOneWidget);
        expect(find.textContaining('private'), findsNothing);
        expect(
          f.container.read(providerEntryGateProvider).asData!.value,
          isA<Failure<bool>>(),
        );
        expect(f.storage.clears, 0);
        f.adapter.completionStatus = 200;
        f.adapter.completionTransportFailure = null;
        f.adapter.completionBody = null;
        await tester.tap(find.text('Retry account setup'));
        await tester.pumpAndSettle();
        expect(f.path, AppRoutes.home);
        expect(f.adapter.matching('/providers/me/completion').length, 2);
      },
    );
  }

  testWidgets(
    'profile rejection retains details and values, double submission prevented, retry succeeds',
    (tester) async {
      f.storage.session = testSession();
      f.adapter.completion['profileCompleted'] = false;
      f.adapter.profileStatus = 400;
      await f.pump(tester);
      await fillProfile(tester);
      f.adapter.pendingProfile = Completer<void>();
      await saveProfile(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        f.container.read(providerProfileControllerProvider).loading,
        isTrue,
      );
      // Controller-level duplicate calls are guarded as well as the disabled CTA.
      final current = f.adapter.matching('/providers/me/profile').single;
      expect(current.data['marketId'], 42);
      await tester.tap(find.text('Save profile'), warnIfMissed: false);
      await tester.pump();
      expect(f.adapter.matching('/providers/me/profile').length, 1);
      f.adapter.pendingProfile!.complete();
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.profile);
      expect(
        f.container.read(providerProfileControllerProvider).loading,
        isFalse,
      );
      expect(
        find.text('Please check your profile details and try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(auth_ui.field('First name'))
            .controller!
            .text,
        ' Jane ',
      );
      f.adapter.pendingProfile = null;
      f.adapter.profileStatus = 200;
      await saveProfile(tester);
      await tester.pumpAndSettle();
      expect(f.path, AppRoutes.home);
      expect(f.adapter.matching('/providers/me/profile').length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'details requires visible fields and keeps optional data optional',
    (tester) async {
      f.storage.session = testSession();
      f.adapter.completion['marketSelected'] = false;
      await f.pump(tester);
      await select(tester, 'profile-market', 'API market');
      await saveProfile(tester);
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(find.text('Select your date of birth.'), findsOneWidget);
      expect(find.text('Select your gender.'), findsOneWidget);
      expect(f.adapter.matching('/providers/me/profile'), isEmpty);
      expect(find.byKey(const ValueKey('profile-availability')), findsNothing);
    },
  );

  testWidgets('market failure retries and empty result disables save', (
    tester,
  ) async {
    f.storage.session = testSession();
    f.adapter.completion['profileCompleted'] = false;
    f.adapter.marketStatus = 500;
    await f.pump(tester);
    expect(find.text('Retry markets'), findsOneWidget);
    f.adapter.marketStatus = 200;
    f.adapter.markets = [];
    await tester.ensureVisible(find.text('Retry markets'));
    await tester.tap(find.text('Retry markets'));
    await tester.pumpAndSettle();
    expect(find.text('No markets are currently available.'), findsOneWidget);
    expect(
      tester
          .widget<BThereButton>(
            find.widgetWithText(BThereButton, 'Save profile'),
          )
          .onPressed,
      isNull,
    );
    expect(f.adapter.matching('/providers/me/profile'), isEmpty);
  });

  testWidgets(
    'password login uses identifier and enters details when profile incomplete',
    (tester) async {
      f.adapter.completion['profileCompleted'] = false;
      await f.pump(tester);
      await tester.enterText(auth_ui.field('Email address'), ' provider ');
      await tester.enterText(auth_ui.field('Password'), ' password 10 ');
      await tester.ensureVisible(find.widgetWithText(BThereButton, 'Sign in'));
      await tester.tap(find.widgetWithText(BThereButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(f.adapter.matching('/auth/login').single.data, {
        'identifier': 'provider',
        'password': ' password 10 ',
      });
      expect(f.storage.writes, 1);
      expect(f.path, AppRoutes.profile);
    },
  );
}
