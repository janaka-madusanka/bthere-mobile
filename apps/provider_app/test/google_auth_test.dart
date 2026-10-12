import 'support/fake_service_repository.dart';
import 'support/fake_completion_repository.dart';

import 'dart:async';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/core/session/app_session_state.dart';
import 'package:provider_app/features/auth/application/google_auth_controller.dart';
import 'package:provider_app/features/auth/data/google_sign_in_identity_provider.dart';
import 'package:provider_app/features/auth/domain/google_identity_provider.dart';
import 'package:provider_app/features/auth/widgets/google_auth_button.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_google_identity_provider.dart';
import 'support/fake_session_storage.dart';

void main() {
  late FakeAuthRepository repo;
  late FakeGoogleIdentityProvider identity;
  late FakeSessionStorage storage;
  late ProviderContainer container;
  setUp(() {
    repo = FakeAuthRepository();
    identity = FakeGoogleIdentityProvider();
    storage = FakeSessionStorage();
    container = ProviderContainer(
      overrides: [
        providerServiceRepositoryProvider.overrideWithValue(
          FakeServiceRepository(),
        ),
        providerCompletionRepositoryProvider.overrideWithValue(
          FakeCompletionRepository(),
        ),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        providerAuthRepositoryProvider.overrideWithValue(repo),
        googleIdentityProvider.overrideWithValue(identity),
        sessionStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(() => testNow),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No live network in tests'),
        ),
      ],
    );
    container.listen(googleAuthControllerProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BThereProviderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  GoogleAuthController controller() =>
      container.read(googleAuthControllerProvider.notifier);

  test('loading blocks duplicate identity and backend operations', () async {
    identity.pending = Completer<String?>();
    repo.pendingGoogle = Completer<Result<AuthUser>>();
    final request = controller().submit();
    expect(container.read(googleAuthControllerProvider).loading, isTrue);
    await controller().submit();
    expect(identity.calls, 1);
    identity.pending!.complete('synthetic-google-id');
    await Future<void>.delayed(Duration.zero);
    await controller().submit();
    expect(repo.googleAuthentications, 1);
    expect(repo.googleToken == 'synthetic-google-id', isTrue);
    repo.pendingGoogle!.complete(
      const Failure(AppFailure(message: 'Try again.', code: 'EXPECTED')),
    );
    await request;
    expect(container.read(googleAuthControllerProvider).loading, isFalse);
  });

  test('cancellation returns idle without session and allows retry', () async {
    identity.token = null;
    await controller().submit();
    final state = container.read(googleAuthControllerProvider);
    expect(state.loading, isFalse);
    expect(state.failure, isNull);
    expect(state.value, isNull);
    expect(repo.googleAuthentications, 0);
    expect(storage.writes, 0);
    identity.token = 'synthetic-google-id';
    await controller().submit();
    expect(identity.calls, 2);
    expect(repo.googleAuthentications, 1);
  });

  test('missing token is safe failure without exchange', () async {
    identity.token = ' ';
    await controller().submit();
    expect(
      container.read(googleAuthControllerProvider).failure!.code,
      'GOOGLE_ID_TOKEN_MISSING',
    );
    expect(repo.googleAuthentications, 0);
    expect(storage.writes, 0);
  });

  for (final failure in [
    googleConfigurationFailure,
    googleMissingTokenFailure,
    googleIdentityOperationFailure,
  ]) {
    test('identity failure ${failure.code} stays safe and idle', () async {
      identity.error = GoogleIdentityFailure(failure);
      await controller().submit();
      final state = container.read(googleAuthControllerProvider);
      expect(state.loading, isFalse);
      expect(state.failure!.code, failure.code);
      expect(state.failure!.cause, isNull);
      expect(repo.googleAuthentications, 0);
    });
  }

  test(
    'unexpected identity error does not leak credentials or exceptions',
    () async {
      identity.error = StateError(
        'synthetic-google-id synthetic-access synthetic-refresh',
      );
      await controller().submit();
      final state = container.read(googleAuthControllerProvider);
      expect(state.failure!.code, 'AUTH_UI_OPERATION_FAILED');
      expect(state.failure!.cause, isNull);
      expect(state.failure!.message.contains('synthetic'), isFalse);
    },
  );

  test('success refreshes authoritative local session, state contains safe user only', () async {
    container.listen(appSessionStateProvider, (_, _) {});
    expect(
      await container.read(appSessionStateProvider.future),
      AppSessionState.unauthenticated,
    );
    repo.persistVerifiedSession = () => storage.write(testSession());
    await controller().submit();
    expect(
      await container.read(appSessionStateProvider.future),
      AppSessionState.authenticated,
    );
    expect(storage.writes, 1);
    expect(storage.reads, 2);
    final state = container.read(googleAuthControllerProvider);
    expect(state.value, same(testAuthUser));
    expect(state.failure, isNull);
    expect(state.toString().contains('synthetic-google-id'), isFalse);
    expect(state.value.toString().contains('synthetic-access'), isFalse);
  });

  test('disposal during account chooser prevents backend exchange', () async {
    identity.pending = Completer<String?>();
    final operation = controller().submit();
    container.dispose();
    identity.pending!.complete('synthetic-google-id');
    await operation;
    expect(repo.googleAuthentications, 0);
  });

  test(
    'controller disposal during backend exchange skips session refresh',
    () async {
      repo.pendingGoogle = Completer<Result<AuthUser>>();
      final operation = controller().submit();
      await Future<void>.delayed(Duration.zero);
      container.invalidate(googleAuthControllerProvider);
      repo.pendingGoogle!.complete(Success(testAuthUser));
      await operation;
      expect(storage.reads, 0);
    },
  );

  test(
    'missing server client ID is controlled without initializing plugin',
    () async {
      final adapter = GoogleSignInIdentityProvider(serverClientId: ' ');
      await expectLater(
        adapter.requestIdToken(),
        throwsA(
          isA<GoogleIdentityFailure>().having(
            (e) => e.failure.code,
            'code',
            'GOOGLE_CONFIGURATION_REQUIRED',
          ),
        ),
      );
      expect(
        AppConfig(apiBaseUrl: 'https://example.invalid').googleServerClientId,
        isEmpty,
      );
    },
  );

  testWidgets(
    'dormant Google button retains loading and duplicate-tap behavior in isolation',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: BThereTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => GoogleAuthButton(
                  loading: ref.watch(googleAuthControllerProvider).loading,
                  onPressed: () =>
                      ref.read(googleAuthControllerProvider.notifier).submit(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      identity.pending = Completer<String?>();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      final buttons = tester.widgetList<BThereButton>(
        find.byType(BThereButton),
      );
      expect(buttons.length, 1);
      expect(buttons.last.loading, isTrue);
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(identity.calls, 1);
      identity.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Google success waits for persistence then router reaches Home', (
    tester,
  ) async {
    await pumpApp(tester);
    final gate = Completer<void>();
    repo.persistVerifiedSession = () async {
      await gate.future;
      await storage.write(testSession());
    };
    final operation = controller().submit();
    await tester.pump();
    expect(container.read(googleAuthControllerProvider).loading, isTrue);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.auth,
    );
    gate.complete();
    await operation;
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    expect(find.text('Continue with Google'), findsNothing);
  });

  for (final code in [
    'NETWORK_CONNECTIONERROR',
    'AUTH_WRONG_ACCOUNT_TYPE',
    'SESSION_PERSIST_FAILED',
  ]) {
    testWidgets('backend failure $code stays in auth and permits retry', (
      tester,
    ) async {
      repo.googleResult = Failure(
        AppFailure(
          message: 'Please try again.',
          code: code,
          cause: StateError('synthetic-google-id'),
        ),
      );
      await pumpApp(tester);
      await controller().submit();
      await tester.pumpAndSettle();
      expect(
        container.read(googleAuthControllerProvider).failure!.message,
        'Please try again.',
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.auth,
      );
      expect(
        container.read(googleAuthControllerProvider).failure!.cause,
        isNull,
      );
      expect(storage.writes, 0);
      await controller().submit();
      await tester.pumpAndSettle();
      expect(identity.calls, 2);
    });
  }

  testWidgets(
    'dormant Google failure does not affect email entry or navigation',
    (tester) async {
      identity.error = const GoogleIdentityFailure(googleConfigurationFailure);
      await pumpApp(tester);
      await controller().submit();
      await tester.pumpAndSettle();
      expect(
        container.read(googleAuthControllerProvider).failure!.code,
        'GOOGLE_CONFIGURATION_REQUIRED',
      );
      expect(find.text(googleConfigurationFailure.message), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-create-account-tab')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.emailRegistration,
      );
    },
  );

  for (final failedRead in [false, true]) {
    testWidgets(
      'Google repository success with ${failedRead ? 'failed' : 'missing'} local session never reaches Home',
      (tester) async {
        await pumpApp(tester);
        if (failedRead) storage.failRead = true;
        await controller().submit();
        await tester.pumpAndSettle();
        final path = container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path;
        expect(path, failedRead ? AppRoutes.startup : AppRoutes.auth);
        expect(path, isNot(AppRoutes.home));
      },
    );
  }
}
