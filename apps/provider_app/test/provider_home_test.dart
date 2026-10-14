import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';

import 'support/fake_completion_repository.dart';
import 'support/fake_service_repository.dart';

import 'service_first_test.dart' show ServiceFixture, pump;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'registered greeting fits fallback glyphs and loaded sub services',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = ServiceFixture(existing: true);
      final session = f.storage.session!;
      f.storage.session = AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        tokenType: session.tokenType,
        expiresAt: session.expiresAt,
        user: SessionUser(
          id: 1,
          username: 'විශ්ව 👩🏽‍⚕️',
          status: 'ACTIVE',
          roles: ['PROVIDER'],
        ),
      );
      await pump(tester, f, route: AppRoutes.home);
      expect(find.textContaining('විශ්ව'), findsOneWidget);
      expect(find.text('Home care'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.1, 1.3]) {
    for (final existing in [false, true]) {
      testWidgets('home text scale $scale existing=$existing has no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(
          tester,
          ServiceFixture(existing: existing),
          route: AppRoutes.home,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final existing in [false, true]) {
    for (final width in [320.0, 430.0]) {
      testWidgets('home existing=$existing at width=$width', (tester) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = ServiceFixture(existing: existing);
        await pump(tester, f, route: AppRoutes.home);
        expect(
          find.text(
            existing
                ? 'Your Registered Services'
                : 'Register your first service',
          ),
          findsOneWidget,
        );
        expect(find.text('Sarah Wilson'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('registration lookup failure can retry', (tester) async {
    final f = ServiceFixture();
    f.services.assignments = const Failure(AppFailure(message: 'Offline'));
    await pump(tester, f, route: AppRoutes.home);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(f.services.assignmentLoads, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'registered service selects dashboard even without completion rows',
    (tester) async {
      final f = ServiceFixture(existing: true);
      f.completion.result = Success(
        parseProviderCompletion(completionJson()..['services'] = []),
      );
      await pump(tester, f, route: AppRoutes.home);
      expect(find.text('Your Registered Services'), findsOneWidget);
      expect(find.text('Register your first service'), findsNothing);
    },
  );
  testWidgets(
    'no assignments selects welcome even with stale completion rows',
    (tester) async {
      final f = ServiceFixture(existing: false);
      f.completion.result = Success(parseProviderCompletion(completionJson()));
      await pump(tester, f, route: AppRoutes.home);
      expect(find.text('Register your first service'), findsOneWidget);
      expect(find.text('Your Registered Services'), findsNothing);
    },
  );
  for (final verification in ['PENDING', 'REJECTED', 'APPROVED']) {
    testWidgets('$verification registered service remains on dashboard', (
      tester,
    ) async {
      final f = ServiceFixture(existing: true);
      f.services.assignments = Success([
        parseProviderServiceAssignment(
          assignmentJson()..['verificationStatus'] = verification,
        ),
      ]);
      await pump(tester, f, route: AppRoutes.home);
      expect(find.text('Your Registered Services'), findsOneWidget);
      expect(find.text('Register your first service'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final existing in [false, true]) {
    testWidgets('Figma layout reference ${existing ? "registered" : "new"}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final f = ServiceFixture(existing: existing);
      if (existing) {
        f.services.assignments = Success([
          for (final (index, name) in [
            'Caregiving',
            'Meal Preparation',
            'Pet Care',
          ].indexed)
            parseProviderServiceAssignment(
              assignmentJson(typeId: index + 20)
                ..['assignmentId'] = index + 20
                ..['providerTypeName'] = name
                ..['verificationStatus'] = 'APPROVED',
            ),
        ]);
      }
      await pump(tester, f, route: AppRoutes.home);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: const RepaintBoundary(
            key: ValueKey('home-preview'),
            child: BThereProviderApp(),
          ),
        ),
      );
      if (existing) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(
              'assets/home/existing_imgOriginalServicePhotograph.png',
            ),
            tester.element(find.byType(RepaintBoundary).first),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('home-preview')),
        matchesGoldenFile(
          'goldens/provider_home_${existing ? "registered" : "new"}.png',
        ),
      );
    });
  }
}
