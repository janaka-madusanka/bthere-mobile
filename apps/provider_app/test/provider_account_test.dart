import 'package:provider_app/features/home/presentation/provider_home_widgets.dart';

import 'dart:async';

import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/bootstrap/app_bootstrap.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/account/application/provider_account_controller.dart';
import 'package:provider_app/features/account/presentation/provider_account_screen.dart';

import 'email_registration_onboarding_test.dart' show OnboardingFixture;
import 'service_first_test.dart' show ServiceFixture, pump, path;
import 'support/fake_session_storage.dart';

AuthSession accountSession() => AuthSession(
  accessToken: 'synthetic-access',
  refreshToken: 'synthetic-refresh',
  tokenType: 'Bearer',
  expiresAt: testNow.add(const Duration(minutes: 15)),
  user: SessionUser(
    id: 12,
    username: 'test.provider',
    email: 'provider@example.invalid',
    status: 'ACTIVE',
    roles: ['SERVICE_PROVIDER'],
  ),
);

void main() {
  testWidgets(
    'Profile opens inside the production bootstrap configuration scope',
    (tester) async {
      final f = OnboardingFixture();
      addTearDown(f.dispose);
      f.storage.session = accountSession();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: AppBootstrap(
            config: AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(BThereProviderApp)),
      );
      scope.read(appRouterProvider).go(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(find.byType(ProviderAccountScreen), findsOneWidget);
      expect(find.text('test.provider'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final email in [null, '', '   ']) {
      testWidgets('Profile handles optional email=$email on $platform', (
        tester,
      ) async {
        final f = OnboardingFixture();
        addTearDown(f.dispose);
        final session = accountSession();
        f.storage.session = AuthSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          tokenType: session.tokenType,
          expiresAt: session.expiresAt,
          user: SessionUser(
            id: 12,
            username: 'test.provider',
            status: 'ACTIVE',
            roles: ['SERVICE_PROVIDER'],
            email: email,
          ),
        );
        await f.pump(tester);
        f.container.read(appRouterProvider).go(AppRoutes.account);
        await tester.pumpAndSettle();
        expect(find.text('test.provider'), findsOneWidget);
        expect(find.text('No rating available'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({platform}));
    }
  }
  testWidgets(
    'Profile opens with real scoped account and completion providers',
    (tester) async {
      final f = OnboardingFixture();
      addTearDown(f.dispose);
      f.storage.session = accountSession();
      await f.pump(tester);
      f.container.read(appRouterProvider).go(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(find.byType(ProviderAccountScreen), findsOneWidget);
      expect(find.text('test.provider'), findsOneWidget);
      expect(find.text('My Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account read errors retry without exposing storage details', (
    tester,
  ) async {
    final f = ServiceFixture();
    f.storage.session = accountSession();
    await pump(tester, f, route: AppRoutes.account);
    f.storage.failRead = true;
    f.container.invalidate(providerAccountProvider);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load account details'), findsOneWidget);
    expect(find.text('Synthetic storage failure'), findsNothing);
    expect(
      find.text('Account details are not available for this session.'),
      findsNothing,
    );
    f.storage.failRead = false;
    await tester.tap(find.text('Retry').last);
    await tester.pumpAndSettle();
    expect(find.text('test.provider'), findsOneWidget);
  });

  test('pending sign out completes after Profile stops listening', () async {
    final storage = _PendingClearStorage()..session = accountSession();
    final container = ProviderContainer(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(providerSignOutProvider, (_, _) {});
    final pending = container.read(providerSignOutProvider.notifier).signOut();
    subscription.close();
    await container.pump();
    storage.clearPending.complete();
    await pending;
    expect(storage.session, isNull);
    expect(storage.clears, 1);
    expect(container.read(providerSignOutProvider).busy, isFalse);
  });
  testWidgets('Profile shows identity and links to service management', (
    tester,
  ) async {
    final f = ServiceFixture();
    f.storage.session = accountSession();
    await pump(tester, f, route: AppRoutes.account);
    expect(find.byType(ProviderAccountScreen), findsOneWidget);
    expect(
      tester.widget<HomeNavigation>(find.byType(HomeNavigation)).selectedIndex,
      4,
    );
    expect(find.text('test.provider'), findsOneWidget);
    expect(find.text('My Account'), findsOneWidget);
    await tester.ensureVisible(find.text('Help & Support'));
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Manage services'));
    await tester.tap(find.text('Manage services'));
    await tester.pumpAndSettle();
    expect(path(f), AppRoutes.services);
  });

  testWidgets('legacy session shows honest unavailable account state', (
    tester,
  ) async {
    final f = ServiceFixture();
    await pump(tester, f, route: null);
    await tester.tap(
      find.descendant(
        of: find.byType(HomeNavigation),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(path(f), AppRoutes.account);
    expect(find.text('Provider account'), findsOneWidget);
    expect(find.text('No rating available'), findsOneWidget);
    expect(find.text('My Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh reloads the profile and retains safe account identity', (
    tester,
  ) async {
    final f = ServiceFixture();
    f.storage.session = accountSession();
    await pump(tester, f, route: AppRoutes.account);
    await tester.ensureVisible(find.text('Privacy & Security'));
    await tester.tap(find.text('Privacy & Security'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Refresh profile'));
    await tester.tap(find.byTooltip('Refresh profile'));
    await tester.pumpAndSettle();
    expect(find.text('test.provider'), findsOneWidget);
    expect(find.text('My Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sign out cancellation retains credentials; confirmation clears before auth route',
    (tester) async {
      final f = ServiceFixture();
      f.storage.session = accountSession();
      await pump(tester, f, route: AppRoutes.account);
      await tester.ensureVisible(find.text('Privacy & Security'));
      await tester.tap(find.text('Privacy & Security'));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('profile-sign-out'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.storage.clears, 0);
      expect(path(f), AppRoutes.account);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Sign out'),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.storage.clears, 1);
      expect(f.storage.session, isNull);
      expect(path(f), AppRoutes.auth);
      expect(find.byType(HomeNavigation), findsNothing);
      expect(find.text('provider@example.invalid'), findsNothing);
    },
  );

  for (final signedIn in [false, true]) {
    testWidgets(
      'Profile deep link preserves ${signedIn ? "incomplete-profile" : "unauthenticated"} gate',
      (tester) async {
        final f = OnboardingFixture();
        addTearDown(f.dispose);
        if (signedIn) {
          f.storage.session = accountSession();
          f.adapter.completion['profileCompleted'] = false;
        }
        await f.pump(tester);
        f.container.read(appRouterProvider).go(AppRoutes.account);
        await tester.pumpAndSettle();
        expect(f.path, signedIn ? AppRoutes.profile : AppRoutes.auth);
        expect(find.byType(ProviderAccountScreen), findsNothing);
      },
    );
  }

  testWidgets(
    'Profile scrolls without overflow on narrow phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final f = ServiceFixture();
      f.storage.session = accountSession();
      await pump(tester, f, route: AppRoutes.account);
      await tester.ensureVisible(find.text('Privacy & Security'));
      await tester.tap(find.text('Privacy & Security'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-sign-out')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeNavigation), findsOneWidget);
    },
  );

  test('sign out waits for clear, blocks duplicates and preserves session on storage failure', () async {
    final storage = _PendingClearStorage()..session = accountSession();
    final container = ProviderContainer(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(providerSignOutProvider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(providerSignOutProvider.notifier);
    final first = controller.signOut();
    await controller.signOut();
    expect(storage.clears, 1);
    expect(container.read(providerSignOutProvider).busy, isTrue);
    expect(storage.session, isNotNull);
    storage.clearPending.completeError(StateError('Sensitive plugin text'));
    await first;
    expect(
      container.read(providerSignOutProvider).error,
      'Unable to sign out. Please try again.',
    );
    expect(container.read(providerSignOutProvider).busy, isFalse);
    expect(storage.session, isNotNull);
  });
}

class _PendingClearStorage extends FakeSessionStorage {
  final clearPending = Completer<void>();
  @override
  Future<void> clear() async {
    clears++;
    await clearPending.future;
    session = null;
  }
}
