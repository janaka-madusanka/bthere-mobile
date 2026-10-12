import 'dart:async';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/auth/application/login_controller.dart';
import 'package:provider_app/features/auth/widgets/auth_flow_switcher.dart';

import 'email_auth_screen_test.dart' as email_flow;
import 'support/fake_auth_repository.dart';
import 'support/fake_session_storage.dart';

Finder get signInAction => find.widgetWithText(BThereButton, 'Sign in');
Finder get signInTab => find.byKey(const ValueKey('auth-sign-in-tab'));
Finder get createTab => find.byKey(const ValueKey('auth-create-account-tab'));

Future<void> fillLogin(
  WidgetTester tester, {
  String email = ' provider@example.com ',
  String password = 'short',
}) async {
  await tester.enterText(email_flow.field('Email address'), email);
  await tester.enterText(email_flow.field('Password'), password);
}

Future<void> pressSignIn(WidgetTester tester) async {
  await tester.ensureVisible(signInAction);
  await tester.tap(signInAction);
  await tester.pump();
}

String path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets(
    'default sign in has selected tab, safe fields and no dormant or unsupported actions',
    (tester) async {
      final container = await email_flow.pumpAuth(
        tester,
        FakeAuthRepository(),
        FakeSessionStorage(),
      );
      expect(find.byType(AuthFlowSwitcher), findsOneWidget);
      expect(
        tester
            .widget<AuthFlowSwitcher>(find.byType(AuthFlowSwitcher))
            .signingIn,
        isTrue,
      );
      expect(signInTab, findsOneWidget);
      expect(createTab, findsOneWidget);
      expect(signInAction, findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(path(container), AppRoutes.auth);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.textContaining('10–72'), findsNothing);
      expect(container.exists(googleIdentityProvider), isFalse);
    },
  );

  testWidgets(
    'tabs switch registration and sign in without carrying passwords',
    (tester) async {
      final container = await email_flow.pumpAuth(
        tester,
        FakeAuthRepository(),
        FakeSessionStorage(),
      );
      await fillLogin(tester);
      await tester.ensureVisible(createTab);
      await tester.tap(createTab);
      await tester.pumpAndSettle();
      expect(path(container), AppRoutes.emailRegistration);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(
        tester
            .widget<AuthFlowSwitcher>(find.byType(AuthFlowSwitcher))
            .signingIn,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(email_flow.field('Password'))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(signInTab);
      await tester.tap(signInTab);
      await tester.pumpAndSettle();
      expect(path(container), AppRoutes.auth);
      expect(
        tester
            .widget<TextFormField>(email_flow.field('Password'))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  for (final credentials in [
    ('', 'password'),
    ('   ', 'password'),
    ('provider@example.com', ''),
  ]) {
    testWidgets(
      'blank credentials ${credentials.$1.isEmpty
          ? 'email'
          : credentials.$2.isEmpty
          ? 'password'
          : 'whitespace email'} are blocked',
      (tester) async {
        final repo = FakeAuthRepository();
        await email_flow.pumpAuth(tester, repo, FakeSessionStorage());
        await fillLogin(
          tester,
          email: credentials.$1,
          password: credentials.$2,
        );
        await pressSignIn(tester);
        expect(repo.logins, 0);
        expect(
          find.text(
            credentials.$2.isEmpty
                ? 'Enter your password.'
                : 'Enter your email.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'valid login sends trimmed identifier and exact password with no registration complexity rule',
    (tester) async {
      final repo = FakeAuthRepository()
        ..loginResult = const Failure(
          AppFailure(message: 'Try again.', code: 'EXPECTED'),
        );
      await email_flow.pumpAuth(tester, repo, FakeSessionStorage());
      await fillLogin(tester, email: ' provider-name ', password: ' p ');
      await pressSignIn(tester);
      await tester.pumpAndSettle();
      expect(repo.logins, 1);
      expect(repo.loginIdentifier, 'provider-name');
      expect(repo.loginPassword == ' p ', isTrue);
      expect(repo.registrations, 0);
    },
  );

  testWidgets(
    'password is obscured by default, proper autofill and safe visibility toggle',
    (tester) async {
      await email_flow.pumpAuth(
        tester,
        FakeAuthRepository(),
        FakeSessionStorage(),
      );
      final password = tester.widget<BThereTextField>(
        email_flow.control('Password'),
      );
      expect(password.obscureText, isTrue);
      expect(password.autofillHints, [AutofillHints.password]);
      final email = tester.widget<BThereTextField>(
        email_flow.control('Email address'),
      );
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(
        email.autofillHints,
        containsAll([AutofillHints.username, AutofillHints.email]),
      );
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      final visible = tester.widget<BThereTextField>(
        email_flow.control('Password'),
      );
      expect(visible.obscureText, isFalse);
      expect(visible.autocorrect, isFalse);
      expect(visible.enableSuggestions, isFalse);
      expect(
        tester
            .widget<AutofillGroup>(find.byType(AutofillGroup))
            .onDisposeAction,
        AutofillContextAction.cancel,
      );
    },
  );

  testWidgets(
    'loading blocks duplicate button/keyboard submits, tabs, fields and visibility',
    (tester) async {
      final repo = FakeAuthRepository()
        ..pendingLogin = Completer<Result<AuthUser>>();
      final container = await email_flow.pumpAuth(
        tester,
        repo,
        FakeSessionStorage(),
      );
      await fillLogin(tester);
      await pressSignIn(tester);
      expect(tester.widget<BThereButton>(signInAction).loading, isTrue);
      expect(
        tester.widget<AuthFlowSwitcher>(find.byType(AuthFlowSwitcher)).busy,
        isTrue,
      );
      expect(
        tester
            .widget<BThereTextField>(email_flow.control('Email address'))
            .enabled,
        isFalse,
      );
      expect(
        tester.widget<BThereTextField>(email_flow.control('Password')).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Show password',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<TextButton>(createTab).onPressed, isNull);
      await tester.tap(signInAction);
      tester
          .widget<BThereTextField>(email_flow.control('Password'))
          .onFieldSubmitted!('ignored');
      await tester.ensureVisible(createTab);
      await tester.tap(createTab);
      await tester.pump();
      expect(repo.logins, 1);
      expect(path(container), AppRoutes.auth);
      repo.pendingLogin!.complete(
        const Failure(AppFailure(message: 'Try again.')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<BThereButton>(signInAction).loading, isFalse);
    },
  );

  for (final code in [
    'NETWORK_BADRESPONSE',
    'AUTH_WRONG_ACCOUNT_TYPE',
    'SESSION_PERSIST_FAILED',
  ]) {
    testWidgets(
      'failure $code retains inputs, stays on sign in and permits retry',
      (tester) async {
        final repo = FakeAuthRepository()
          ..loginResult = Failure(
            AppFailure(
              message: 'Please try again.',
              code: code,
              cause: StateError('synthetic-access'),
            ),
          );
        final storage = FakeSessionStorage();
        final container = await email_flow.pumpAuth(tester, repo, storage);
        await fillLogin(tester);
        await pressSignIn(tester);
        await tester.pumpAndSettle();
        expect(find.text('Please try again.'), findsOneWidget);
        expect(path(container), AppRoutes.auth);
        expect(
          tester
              .widget<TextFormField>(email_flow.field('Email address'))
              .controller!
              .text,
          ' provider@example.com ',
        );
        expect(
          tester
                  .widget<TextFormField>(email_flow.field('Password'))
                  .controller!
                  .text ==
              'short',
          isTrue,
        );
        expect(container.read(loginControllerProvider).failure!.cause, isNull);
        expect(storage.writes, 0);
        await pressSignIn(tester);
        await tester.pumpAndSettle();
        expect(repo.logins, 2);
      },
    );
  }

  testWidgets(
    'login awaits persistence then refreshes session on same router and reaches services',
    (tester) async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final gate = Completer<void>();
      repo.persistVerifiedSession = () async {
        await gate.future;
        await storage.write(testSession());
      };
      final container = await email_flow.pumpAuth(tester, repo, storage);
      final router = container.read(appRouterProvider);
      await fillLogin(tester);
      await pressSignIn(tester);
      expect(path(container), AppRoutes.auth);
      expect(storage.writes, 0);
      expect(container.read(loginControllerProvider).loading, isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(path(container), AppRoutes.home);
      expect(container.read(appRouterProvider), same(router));
      expect(storage.writes, 1);
      expect(storage.reads, 2);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  for (final failRead in [false, true]) {
    testWidgets(
      'success with ${failRead ? 'failed' : 'missing'} local session cannot enter services',
      (tester) async {
        final storage = FakeSessionStorage();
        final container = await email_flow.pumpAuth(
          tester,
          FakeAuthRepository(),
          storage,
        );
        if (failRead) storage.failRead = true;
        await fillLogin(tester);
        await pressSignIn(tester);
        await tester.pumpAndSettle();
        expect(path(container), failRead ? AppRoutes.startup : AppRoutes.auth);
        expect(path(container), isNot(AppRoutes.services));
      },
    );
  }

  testWidgets('unexpected login exception is safe and leaves retry available', (
    tester,
  ) async {
    final repo = FakeAuthRepository()..throwLogin = true;
    final container = await email_flow.pumpAuth(
      tester,
      repo,
      FakeSessionStorage(),
    );
    await fillLogin(tester);
    await pressSignIn(tester);
    await tester.pumpAndSettle();
    expect(
      container.read(loginControllerProvider).failure!.code,
      'AUTH_UI_OPERATION_FAILED',
    );
    expect(find.textContaining('synthetic'), findsNothing);
    expect(path(container), AppRoutes.auth);
  });

  test(
    'controller handles disposal without state mutation or session refresh',
    () async {
      final repo = FakeAuthRepository()
        ..pendingLogin = Completer<Result<AuthUser>>();
      final storage = FakeSessionStorage();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
          providerAuthRepositoryProvider.overrideWithValue(repo),
          sessionStorageProvider.overrideWithValue(storage),
        ],
      );
      container.listen(loginControllerProvider, (_, _) {});
      final request = container
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'provider', password: 'short');
      container.dispose();
      repo.pendingLogin!.complete(Success(testAuthUser));
      await request;
      expect(storage.reads, 0);
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'sign in and tabs fit narrow width, enlarged text and keyboard in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await email_flow.pumpAuth(
          tester,
          FakeAuthRepository(),
          FakeSessionStorage(),
        );
        await tester.ensureVisible(email_flow.field('Password'));
        await tester.tap(email_flow.field('Password'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(signInAction);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Theme.of(tester.element(signInAction)).brightness,
          Brightness.light,
        );
      },
    );
  }
}
