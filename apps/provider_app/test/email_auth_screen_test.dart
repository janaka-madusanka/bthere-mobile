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
import 'package:provider_app/app/bootstrap/app_bootstrap.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/core/session/app_session_state.dart';
import 'package:provider_app/features/auth/application/email_verification_controller.dart';
import 'package:provider_app/features/auth/application/google_auth_controller.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_session_storage.dart';
import 'support/fake_market_repository.dart';

import 'package:provider_app/features/auth/widgets/auth_background.dart';
import 'package:provider_app/features/auth/widgets/auth_brand_header.dart';
import 'package:provider_app/features/auth/widgets/auth_page.dart';

Finder control(String label) => find.byWidgetPredicate(
  (widget) => widget is BThereTextField && widget.label == label,
);
Finder field(String label) =>
    find.descendant(of: control(label), matching: find.byType(TextFormField));

Future<ProviderContainer> pumpAuth(
  WidgetTester tester,
  FakeAuthRepository repo,
  FakeSessionStorage storage,
) async {
  final container = ProviderContainer(
    overrides: [
      providerMarketRepositoryProvider.overrideWithValue(
        FakeMarketRepository(),
      ),
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
      sessionStorageProvider.overrideWithValue(storage),
      clockProvider.overrideWithValue(() => testNow),
      apiClientProvider.overrideWith(
        (ref) => throw StateError('UI tests must never create network'),
      ),
      googleIdentityProvider.overrideWith(
        (ref) =>
            throw StateError('Email UI must never construct Google identity'),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BThereProviderApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> openRegistration(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('auth-create-account-tab')),
  );
  await tester.tap(find.byKey(const ValueKey('auth-create-account-tab')));
  await tester.pumpAndSettle();
}

Future<void> fillRegistration(
  WidgetTester tester, {
  String email = 'provider@example.com',
  String password = '1234567890',
  String? confirm,
}) async {
  await tester.enterText(field('Email address'), email);
  await tester.enterText(field('Password'), password);
  await tester.enterText(field('Confirm password'), confirm ?? password);
}

Future<void> pressCreate(WidgetTester tester) async {
  await tester.ensureVisible(
    find.widgetWithText(BThereButton, 'Create Account'),
  );
  await tester.tap(find.widgetWithText(BThereButton, 'Create Account'));
  await tester.pump();
}

Future<void> openVerification(
  WidgetTester tester,
  ProviderContainer container, {
  String email = 'provider@example.com',
}) async {
  container
      .read(appRouterProvider)
      .go(AppRoutes.emailVerification, extra: EmailVerificationContext(email));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'redesigned entry has hero and noninteractive decoration with an honest email action',
    (tester) async {
      final repo = FakeAuthRepository();
      final container = await pumpAuth(tester, repo, FakeSessionStorage());
      expect(find.byType(AuthBrandHeader), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-marketing-headline')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('auth-sign-in-tab')), findsOneWidget);
      expect(find.byType(AuthBackground), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(AuthBackground),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      expect(find.widgetWithText(BThereButton, 'Sign in'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('or continue with'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);
      expect(container.exists(googleIdentityProvider), isFalse);
      expect(container.exists(googleAuthControllerProvider), isFalse);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      await openRegistration(tester);
      expect(container.exists(googleIdentityProvider), isFalse);
      expect(container.exists(googleAuthControllerProvider), isFalse);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(
        tester.widget<BThereTextField>(control('Email address')).labelPlacement,
        BThereFieldLabelPlacement.above,
      );
      expect(repo.registrations, 0);
    },
  );
  testWidgets('auth content is centered and constrained on wider viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAuth(tester, FakeAuthRepository(), FakeSessionStorage());
    final button = find.byType(BThereButton).first;
    expect(tester.getSize(button).width, AuthPage.maxContentWidth);
    expect(tester.getCenter(button).dx, 500);
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final screen in ['entry', 'registration', 'verification']) {
      testWidgets(
        'redesigned $screen has no overflow in ${brightness.name} at narrow width and large scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2.5;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final container = await pumpAuth(
            tester,
            FakeAuthRepository(),
            FakeSessionStorage(),
          );
          if (screen == 'registration') {
            await tester.ensureVisible(
              find.byKey(const ValueKey('auth-create-account-tab')),
            );
            await openRegistration(tester);
          } else if (screen == 'verification') {
            await openVerification(
              tester,
              container,
              email: 'a-very-long-provider-address@example.com',
            );
          }
          final buttons = find.byType(BThereButton);
          for (final button in buttons.evaluate()) {
            await tester.ensureVisible(find.byWidget(button.widget));
          }
          await tester.pumpAndSettle();
          expect(
            Theme.of(tester.element(buttons.first)).brightness,
            screen == 'verification' ? brightness : Brightness.light,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(AuthBrandHeader), findsOneWidget);
        },
      );
    }
  }
  testWidgets(
    'nested bootstrap composition uses the overridden repository throughout email flow',
    (tester) async {
      final repo = FakeAuthRepository()
        ..verificationResult = const Failure(
          AppFailure(message: 'Try another code.'),
        );
      final storage = FakeSessionStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerMarketRepositoryProvider.overrideWithValue(
              FakeMarketRepository(),
            ),
            providerServiceRepositoryProvider.overrideWithValue(
              FakeServiceRepository(),
            ),
            providerCompletionRepositoryProvider.overrideWithValue(
              FakeCompletionRepository(),
            ),
            providerAuthRepositoryProvider.overrideWithValue(repo),
            sessionStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWith(
              (ref) => throw StateError('Must not create network'),
            ),
          ],
          child: AppBootstrap(
            config: AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openRegistration(tester);
      await fillRegistration(tester);
      await pressCreate(tester);
      await tester.pumpAndSettle();
      await tester.enterText(field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(repo.registrations, 1);
      expect(repo.verifications, 1);
      expect(find.text('Try another code.'), findsOneWidget);
      expect(storage.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'session reread failure after verification displays safe restoration failure',
    (tester) async {
      final storage = FakeSessionStorage();
      final repo = FakeAuthRepository()
        ..persistVerifiedSession = () async {
          await storage.write(testSession());
          storage.failRead = true;
        };
      final container = await pumpAuth(tester, repo, storage);
      await openVerification(tester, container);
      await tester.enterText(field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to restore'), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.startup,
      );
      expect(find.text('Services'), findsNothing);
    },
  );
  testWidgets(
    'entry defaults to sign in and offers email registration; registration fields are obscured with caller-controlled visibility',
    (tester) async {
      final repo = FakeAuthRepository();
      await pumpAuth(tester, repo, FakeSessionStorage());
      expect(
        find.bySemanticsLabel('B there Provider — Care Promise'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auth-create-account-tab')),
        findsOneWidget,
      );
      expect(find.byType(BThereButton), findsNWidgets(3));
      await openRegistration(tester);
      expect(find.byType(BThereTextField), findsNWidgets(3));
      final edits = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(edits[0].keyboardType, TextInputType.emailAddress);
      expect(edits[0].textInputAction, TextInputAction.next);
      expect(edits[1].obscureText, isTrue);
      expect(edits[2].obscureText, isTrue);
      expect(edits[2].textInputAction, TextInputAction.done);
      expect(
        tester
            .widget<AutofillGroup>(find.byType(AutofillGroup))
            .onDisposeAction,
        AutofillContextAction.cancel,
      );
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList()[1]
            .obscureText,
        isFalse,
      );
      expect(repo.registrations, 0);
      final revealed = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList()[1];
      expect(revealed.autocorrect, isFalse);
      expect(revealed.enableSuggestions, isFalse);
    },
  );
  for (final email in ['', '   ', 'not-an-email', 'a@', 'a b@example.com']) {
    testWidgets('registration blocks invalid email "$email"', (tester) async {
      final repo = FakeAuthRepository();
      await pumpAuth(tester, repo, FakeSessionStorage());
      await openRegistration(tester);
      await fillRegistration(tester, email: email);
      await pressCreate(tester);
      expect(repo.registrations, 0);
      expect(
        find.text(
          email.trim().isEmpty ? 'Enter your email.' : 'Enter a valid email.',
        ),
        findsOneWidget,
      );
    });
  }
  for (final length in [0, 9, 10, 72, 73]) {
    testWidgets('registration enforces password boundary $length', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final container = await pumpAuth(tester, repo, storage);
      await openRegistration(tester);
      await fillRegistration(tester, password: 'x' * length);
      await pressCreate(tester);
      await tester.pumpAndSettle();
      final accepted = length == 10 || length == 72;
      expect(repo.registrations, accepted ? 1 : 0);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        accepted ? AppRoutes.emailVerification : AppRoutes.emailRegistration,
      );
      expect(storage.writes, 0);
      expect(storage.session, isNull);
      expect(
        await container.read(appSessionStateProvider.future),
        AppSessionState.unauthenticated,
      );
    });
  }
  testWidgets(
    'password length uses Unicode code points consistently with Auth',
    (tester) async {
      final repo = FakeAuthRepository();
      await pumpAuth(tester, repo, FakeSessionStorage());
      await openRegistration(tester);
      await fillRegistration(tester, password: '😀' * 10);
      await pressCreate(tester);
      await tester.pumpAndSettle();
      expect(repo.registrations, 1);
    },
  );
  testWidgets('mismatched confirmation is blocked', (tester) async {
    final repo = FakeAuthRepository();
    await pumpAuth(tester, repo, FakeSessionStorage());
    await openRegistration(tester);
    await fillRegistration(tester, confirm: 'different password');
    await pressCreate(tester);
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(repo.registrations, 0);
  });
  testWidgets(
    'registration trims email, sends no confirmation, navigates with email-only context and no session',
    (tester) async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final container = await pumpAuth(tester, repo, storage);
      await openRegistration(tester);
      await fillRegistration(tester, email: '  provider@example.com  ');
      await pressCreate(tester);
      await tester.pumpAndSettle();
      final route = container
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri;
      expect(route.path, AppRoutes.emailVerification);
      expect(route.hasQuery, isFalse);
      expect(repo.registrationRequest!.email, 'provider@example.com');
      expect(repo.registrationRequest!.password, '1234567890');
      expect(find.text('provider@example.com'), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.byType(BThereTextField), findsOneWidget);
      expect(storage.writes, 0);
      expect(
        await container.read(appSessionStateProvider.future),
        AppSessionState.unauthenticated,
      );
    },
  );
  testWidgets(
    'registration loading blocks button, keyboard duplicates, fields and back',
    (tester) async {
      final repo = FakeAuthRepository()
        ..pendingRegistration = Completer<Result<RegistrationAccount>>();
      await pumpAuth(tester, repo, FakeSessionStorage());
      await openRegistration(tester);
      await fillRegistration(tester);
      await pressCreate(tester);
      expect(find.byType(BThereLoadingIndicator), findsOneWidget);
      expect(
        tester
            .widget<BThereButton>(
              find.widgetWithText(BThereButton, 'Create Account'),
            )
            .loading,
        isTrue,
      );
      expect(
        tester
            .widgetList<BThereTextField>(find.byType(BThereTextField))
            .every((field) => !field.enabled),
        isTrue,
      );
      await tester.tap(find.widgetWithText(BThereButton, 'Create Account'));
      tester
          .widget<BThereTextField>(control('Confirm password'))
          .onFieldSubmitted!('1234567890');
      expect(repo.registrations, 1);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      repo.pendingRegistration!.complete(Success(testRegistration));
      await tester.pumpAndSettle();
      expect(find.text('Verify your email'), findsOneWidget);
    },
  );
  testWidgets('registration failure preserves email and allows safe retry', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..registrationResult = const Failure(
        AppFailure(
          message: 'Unable to create your account. Try again.',
          code: 'EXPECTED',
        ),
      );
    final container = await pumpAuth(tester, repo, FakeSessionStorage());
    await openRegistration(tester);
    await fillRegistration(tester);
    await pressCreate(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to create your account. Try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: field('Email address'),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'provider@example.com',
    );
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.emailRegistration,
    );
    repo.registrationResult = Success(testRegistration);
    await pressCreate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Verify your email'), findsOneWidget);
  });
  testWidgets(
    'verification blank OTP is blocked; no resend or unsupported length policy',
    (tester) async {
      final repo = FakeAuthRepository()
        ..verificationResult = const Failure(
          AppFailure(message: 'Code was not accepted.'),
        );
      final container = await pumpAuth(tester, repo, FakeSessionStorage());
      await openVerification(tester, container);
      expect(find.text('provider@example.com'), findsOneWidget);
      expect(find.textContaining('Resend'), findsNothing);
      await tester.enterText(field('Verification code'), '   ');
      await tester.tap(find.text('Verify email'));
      await tester.pump();
      expect(find.text('Enter your verification code.'), findsOneWidget);
      expect(repo.verifications, 0);
      await tester.enterText(field('Verification code'), ' 12 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.verifications, 1);
      expect(repo.verificationRequest!.otp, '12');
      expect(repo.verificationRequest!.email, 'provider@example.com');
    },
  );
  testWidgets(
    'verification loading blocks duplicates and failure keeps OTP for retry',
    (tester) async {
      final repo = FakeAuthRepository()
        ..pendingVerification = Completer<Result<AuthUser>>();
      final container = await pumpAuth(tester, repo, FakeSessionStorage());
      await openVerification(tester, container);
      await tester.enterText(field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pump();
      await tester.tap(find.text('Verify email'));
      tester
          .widget<BThereTextField>(control('Verification code'))
          .onFieldSubmitted!('123456');
      expect(repo.verifications, 1);
      expect(
        tester.widget<BThereTextField>(find.byType(BThereTextField)).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Change email'))
            .onPressed,
        isNull,
      );
      repo.pendingVerification!.complete(
        const Failure(AppFailure(message: 'Code could not be verified.')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Code could not be verified.'), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.emailVerification,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '123456',
      );
      expect(
        tester.widget<BThereButton>(find.byType(BThereButton)).loading,
        isFalse,
      );
      repo.pendingVerification = null;
      repo.persistVerifiedSession = () =>
          container.read(sessionStorageProvider).write(testSession());
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(find.text('Provider Details'), findsOneWidget);
    },
  );
  testWidgets(
    'successful verification waits for repository persistence then rereads session on same router',
    (tester) async {
      final storage = FakeSessionStorage();
      final persisted = Completer<void>();
      final repo = FakeAuthRepository()
        ..persistVerifiedSession = () async {
          await persisted.future;
          await storage.write(testSession());
        };
      final container = await pumpAuth(tester, repo, storage);
      final router = container.read(appRouterProvider);
      await openVerification(tester, container);
      await tester.enterText(field('Verification code'), '123456');
      await tester.tap(find.text('Verify email'));
      await tester.pump();
      expect(storage.writes, 0);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.emailVerification,
      );
      expect(find.byType(BThereLoadingIndicator), findsOneWidget);
      persisted.complete();
      await tester.pumpAndSettle();
      expect(storage.writes, 1);
      expect(storage.reads, 2);
      expect(
        await container.read(appSessionStateProvider.future),
        AppSessionState.authenticated,
      );
      expect(container.read(appRouterProvider), same(router));
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.profile);
      expect(find.text('Provider Details'), findsOneWidget);
      expect(field('Verification code'), findsNothing);
    },
  );
  for (final extra in [
    null,
    'provider@example.com',
    const EmailVerificationContext(''),
  ]) {
    testWidgets(
      'missing/invalid verification route context recovers ($extra)',
      (tester) async {
        final repo = FakeAuthRepository();
        final container = await pumpAuth(tester, repo, FakeSessionStorage());
        container
            .read(appRouterProvider)
            .go(AppRoutes.emailVerification, extra: extra);
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
        expect(
          find.byKey(const ValueKey('auth-create-account-tab')),
          findsOneWidget,
        );
        expect(repo.verifications, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'change email discards OTP and returns to registration without submission',
    (tester) async {
      final repo = FakeAuthRepository();
      final container = await pumpAuth(tester, repo, FakeSessionStorage());
      await openVerification(tester, container);
      await tester.enterText(field('Verification code'), '123456');
      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('auth-create-account-tab')),
        findsOneWidget,
      );
      expect(repo.verifications, 0);
    },
  );
  testWidgets('authenticated users cannot enter any email auth route', (
    tester,
  ) async {
    final container = await pumpAuth(
      tester,
      FakeAuthRepository(),
      FakeSessionStorage()..session = testSession(),
    );
    for (final route in [
      AppRoutes.auth,
      AppRoutes.emailRegistration,
      AppRoutes.emailVerification,
    ]) {
      container
          .read(appRouterProvider)
          .go(
            route,
            extra: const EmailVerificationContext('provider@example.com'),
          );
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.home,
      );
      expect(find.text('Services'), findsOneWidget);
    }
  });
  for (final verification in [false, true]) {
    testWidgets(
      'narrow ${verification ? 'verification' : 'registration'} form supports large text and keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await pumpAuth(
          tester,
          FakeAuthRepository(),
          FakeSessionStorage(),
        );
        if (verification) {
          await openVerification(
            tester,
            container,
            email: 'a-very-long-provider-address@example.com',
          );
        } else {
          await tester.ensureVisible(
            find.byKey(const ValueKey('auth-create-account-tab')),
          );
          await openRegistration(tester);
        }
        final target = field(
          verification ? 'Verification code' : 'Confirm password',
        );
        await tester.ensureVisible(target);
        await tester.showKeyboard(target);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(
            BThereButton,
            verification ? 'Verify email' : 'Create Account',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );
  }
}
