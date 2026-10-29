import 'support/fake_provider_session_api.dart';

import 'package:provider_app/core/auth/provider_session_api.dart';

import 'support/fake_service_repository.dart';
import 'support/fake_completion_repository.dart';

import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/bootstrap/app_bootstrap.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';

import 'support/fake_session_storage.dart';

import 'package:provider_app/features/home/presentation/provider_home_screen.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('shared theme follows system ${brightness.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerServiceRepositoryProvider.overrideWithValue(
              FakeServiceRepository(),
            ),
            providerCompletionRepositoryProvider.overrideWithValue(
              FakeCompletionRepository(),
            ),
            sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
          ],
          child: AppBootstrap(
            config: AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      final context = tester.element(
        find.byKey(const ValueKey('auth-marketing-headline')),
      );
      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).colorScheme.primary, BThereColors.primaryAction);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(BThereButton), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
  for (final failRead in [false, true]) {
    testWidgets(
      'narrow large-text ${failRead ? 'failure' : 'auth'} placeholder stays scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = FakeSessionStorage()..failRead = failRead;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              providerServiceRepositoryProvider.overrideWithValue(
                FakeServiceRepository(),
              ),
              providerCompletionRepositoryProvider.overrideWithValue(
                FakeCompletionRepository(),
              ),
              sessionStorageProvider.overrideWithValue(store),
            ],
            child: AppBootstrap(
              config: AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(
          failRead
              ? find.text('B there Provider')
              : find.bySemanticsLabel('B there Provider — Care Promise'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'ProviderScope bootstrap renders MaterialApp.router and auth placeholder',
    (tester) async {
      final store = FakeSessionStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerServiceRepositoryProvider.overrideWithValue(
              FakeServiceRepository(),
            ),
            providerCompletionRepositoryProvider.overrideWithValue(
              FakeCompletionRepository(),
            ),
            sessionStorageProvider.overrideWithValue(store),
          ],
          child: AppBootstrap(
            config: AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey('auth-marketing-headline')),
        findsOneWidget,
      );
      expect(store.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('checking shows startup then auth without recreating router', (
    tester,
  ) async {
    final store = FakeSessionStorage()..pending = Completer<AuthSession?>();
    final container = ProviderContainer(
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
        sessionStorageProvider.overrideWithValue(store),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('Must not create network'),
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
    await tester.pump();
    final router = container.read(appRouterProvider);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.startup);
    store.pending!.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('auth-marketing-headline')),
      findsOneWidget,
    );
    expect(container.read(appRouterProvider), same(router));
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.auth);
    router.go(AppRoutes.services);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.auth);
    expect(store.reads, 1);
    expect(tester.takeException(), isNull);
  });
  for (final expired in [false, true]) {
    testWidgets(
      'persisted ${expired ? 'expired' : 'valid'} session routes safely',
      (tester) async {
        final store = FakeSessionStorage()
          ..session = testSession(expired: expired);
        final container = ProviderContainer(
          overrides: [
            providerSessionApiProvider.overrideWithValue(
              RejectedProviderSessionApi(),
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
            sessionStorageProvider.overrideWithValue(store),
            clockProvider.overrideWithValue(() => testNow),
            apiClientProvider.overrideWith(
              (ref) => throw StateError('Must not create network'),
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
        expect(
          expired
              ? find.byKey(const ValueKey('auth-marketing-headline'))
              : find.byType(ProviderHomeScreen),
          findsOneWidget,
        );
        final router = container.read(appRouterProvider);
        expect(
          router.routeInformationProvider.value.uri.path,
          expired ? AppRoutes.auth : AppRoutes.home,
        );
        router.go(expired ? AppRoutes.services : AppRoutes.auth);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          expired ? AppRoutes.auth : AppRoutes.home,
        );
        expect(store.clears, 0);
        expect(store.session, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'missing config shows explicit failure rather than infinite spinner',
    (tester) async {
      await tester.pumpWidget(const AppBootstrap(config: null));
      await tester.pumpAndSettle();
      expect(find.textContaining('BTHERE_API_BASE_URL'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'storage failure displays safe startup failure without redirect loop',
    (tester) async {
      final store = FakeSessionStorage()..failRead = true;
      await tester.pumpWidget(
        ProviderScope(
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
            sessionStorageProvider.overrideWithValue(store),
          ],
          child: const BThereProviderApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to restore'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Synthetic'), findsNothing);
      expect(store.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
