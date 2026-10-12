import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/features/auth/widgets/auth_brand_image.dart';

import 'email_auth_screen_test.dart' as auth;
import 'email_registration_onboarding_test.dart' as flow;
import 'support/fake_session_storage.dart';

void main() {
  late flow.OnboardingFixture fixture;
  setUp(() {
    fixture = flow.OnboardingFixture();
    fixture.storage.session = testSession();
    fixture.adapter.completion['profileCompleted'] = false;
  });
  tearDown(() => fixture.dispose());

  testWidgets(
    'details shares auth branding, field styling and safe disabled save',
    (tester) async {
      await fixture.pump(tester);
      expect(find.text('Provider Details'), findsOneWidget);
      expect(find.text('B there Provider'), findsOneWidget);
      expect(find.byType(BThereBrandedBackground), findsOneWidget);
      expect(
        tester.widget<AuthBrandImage>(find.byType(AuthBrandImage)).asset,
        AuthBrandAsset.carePromise,
      );
      expect(find.text('Enter your first name'), findsOneWidget);
      expect(find.text('Enter your last name'), findsOneWidget);
      expect(find.text('Select your date of birth'), findsOneWidget);
      expect(find.text('Select your gender'), findsOneWidget);
      expect(find.text('Select your market'), findsOneWidget);
      final button = find.widgetWithText(BThereButton, 'Save profile');
      expect(tester.widget<BThereButton>(button).onPressed, isNull);
      expect(
        Theme.of(tester.element(button)).colorScheme.primary,
        BThereColors.primaryAction,
      );
      expect(
        tester
            .widget<BThereTextField>(auth.control('Bio (optional)'))
            .validator,
        isNull,
      );
      expect(fixture.adapter.matching('/markets').length, 1);
      expect(fixture.adapter.matching('/providers/me/profile'), isEmpty);
    },
  );

  testWidgets(
    'inline market loading keeps names editable then reveals live choices',
    (tester) async {
      fixture.adapter.pendingMarket = Completer<void>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: const BThereProviderApp(),
        ),
      );
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Loading markets…'), findsOneWidget);
      expect(find.byType(BThereLoadingIndicator), findsOneWidget);
      await tester.enterText(auth.field('First name'), 'Typed while loading');
      expect(
        tester.widget<TextFormField>(auth.field('First name')).enabled,
        isTrue,
      );
      expect(
        tester
            .widget<BThereButton>(
              find.widgetWithText(BThereButton, 'Save profile'),
            )
            .onPressed,
        isNull,
      );
      fixture.adapter.pendingMarket!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(auth.field('First name')).controller!.text,
        'Typed while loading',
      );
      expect(find.byKey(const ValueKey('profile-market')), findsOneWidget);
      expect(fixture.adapter.matching('/markets').length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save keeps geometry during pending request and preserves exact optional payload',
    (tester) async {
      await fixture.pump(tester);
      await flow.fillProfile(tester);
      final button = find.widgetWithText(BThereButton, 'Save profile');
      await tester.ensureVisible(button);
      final size = tester.getSize(button);
      fixture.adapter.profileStatus = 400;
      fixture.adapter.pendingProfile = Completer<void>();
      await flow.saveProfile(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(button), size);
      expect(tester.widget<BThereButton>(button).loading, isTrue);
      await tester.tap(button);
      await tester.pump();
      final request = fixture.adapter.matching('/providers/me/profile').single;
      expect(request.method, 'PUT');
      expect(request.data, {
        'firstName': 'Jane',
        'lastName': 'Doe',
        'dateOfBirth': '2030-01-02',
        'gender': 'MALE',
        'availabilityStatus': 'AVAILABLE',
        'marketId': 42,
        'nicNumber': null,
        'passportNumber': null,
        'profilePhoto': null,
        'bio': null,
      });
      fixture.adapter.pendingProfile!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(BThereInlineError), findsOneWidget);
      expect(
        find.text('Please check your profile details and try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(auth.field('First name')).controller!.text,
        ' Jane ',
      );
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'details scrolls with keyboard and 2.5x text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await fixture.pump(tester);
        await tester.enterText(auth.field('First name'), 'Jane');
        await tester.enterText(auth.field('Last name'), 'Doe');
        await tester.enterText(
          auth.field('Bio (optional)'),
          'Optional biography',
        );
        final button = find.widgetWithText(BThereButton, 'Save profile');
        await tester.ensureVisible(button);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(280));
        expect(Theme.of(tester.element(button)).brightness, Brightness.light);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
