import 'dart:ui' as ui;

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';
import 'package:provider_app/features/onboarding/markets/application/provider_market_controller.dart';

import 'email_auth_screen_test.dart' as auth;
import 'email_registration_onboarding_test.dart' as flow;
import 'support/fake_market_repository.dart';
import 'support/fake_session_storage.dart';

void main() {
  late flow.OnboardingFixture fixture;
  setUp(() {
    fixture = flow.OnboardingFixture();
    fixture.storage.session = testSession();
    fixture.adapter.completion['profileCompleted'] = false;
  });
  tearDown(() => fixture.dispose());

  for (final gender in ProviderGender.values) {
    testWidgets(
      '${gender.label} sheet selection restores and sends ${gender.wireValue}',
      (tester) async {
        await fixture.pump(tester);
        await flow.fillProfile(tester);
        final field = find.byKey(const ValueKey('profile-gender'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(find.text('Select gender'), findsOneWidget);
        for (final supported in ProviderGender.values) {
          expect(
            find.widgetWithText(ListTile, supported.label),
            findsOneWidget,
          );
        }
        await tester.tap(find.widgetWithText(ListTile, gender.label));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          tester
              .widget<BThereSelectorField<ProviderGender>>(field)
              .initialValue,
          gender,
        );
        await tester.tap(field);
        await tester.pumpAndSettle();
        final selected = find.byKey(
          ValueKey('selector-option-${gender.index}'),
        );
        expect(
          tester
              .getSemantics(selected)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(
          tester.getSize(find.widgetWithText(ListTile, gender.label)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.widgetWithText(ListTile, gender.label));
        await tester.pumpAndSettle();
        await flow.saveProfile(tester);
        await tester.pumpAndSettle();
        expect(
          fixture.adapter
              .matching('/providers/me/profile')
              .single
              .data['gender'],
          gender.wireValue,
        );
        expect(fixture.path, '/home');
      },
    );
  }

  testWidgets(
    'market sheet uses API names and preserves numeric identity after reopening',
    (tester) async {
      fixture.adapter.markets = [
        marketJson(id: 71, name: 'First API market'),
        marketJson(id: 98, name: 'Second API market'),
      ];
      await fixture.pump(tester);
      await tester.enterText(auth.field('First name'), 'Jane');
      await tester.enterText(auth.field('Last name'), 'Doe');
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('profile-date-of-birth'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await flow.select(tester, 'profile-gender', 'Male');
      final field = find.byKey(const ValueKey('profile-market'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.text('Select market'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'First API market'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Second API market'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Second API market'), findsOneWidget);
      expect(tester.widget<BThereSelectorField<int>>(field).initialValue, 98);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Second API market'),
            )
            .selected,
        isTrue,
      );
      expect(fixture.adapter.matching('/markets').length, 1);
      await tester.tap(find.widgetWithText(ListTile, 'Second API market'));
      await tester.pumpAndSettle();
      await flow.saveProfile(tester);
      await tester.pumpAndSettle();
      expect(
        fixture.adapter
            .matching('/providers/me/profile')
            .single
            .data['marketId'],
        98,
      );
    },
  );

  testWidgets(
    'opening gender dismisses name keyboard without a text input selector',
    (tester) async {
      await fixture.pump(tester);
      await tester.enterText(auth.field('Last name'), 'Doe');
      expect(tester.testTextInput.isVisible, isTrue);
      final field = find.byKey(const ValueKey('profile-gender'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        find.descendant(of: field, matching: find.byType(TextField)),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Male'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets('cancelling gender sheet preserves the existing selection', (
    tester,
  ) async {
    await fixture.pump(tester);
    await flow.select(tester, 'profile-gender', 'Male');
    final field = find.byKey(const ValueKey('profile-gender'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.widget<BThereSelectorField<ProviderGender>>(field).initialValue,
      ProviderGender.male,
    );
    expect(fixture.adapter.matching('/providers/me/profile'), isEmpty);
  });

  testWidgets('market refresh cannot select a removed open-sheet option', (
    tester,
  ) async {
    await fixture.pump(tester);
    await flow.select(tester, 'profile-market', 'API market');
    final field = find.byKey(const ValueKey('profile-market'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    fixture.adapter.markets = [
      marketJson(id: 99, name: 'Replacement API market'),
    ];
    fixture.container.read(providerMarketControllerProvider.notifier).reload();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'API market'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.widget<BThereSelectorField<int>>(field).initialValue, isNull);
    expect(
      tester
          .widget<BThereButton>(
            find.widgetWithText(BThereButton, 'Save profile'),
          )
          .onPressed,
      isNull,
    );
    expect(fixture.adapter.matching('/providers/me/profile'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long market sheet scrolls at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    fixture.adapter.markets = List.generate(
      30,
      (i) => marketJson(id: i + 1, name: 'API Market ${i + 1}'),
    );
    await fixture.pump(tester);
    final field = find.byKey(const ValueKey('profile-market'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('API Market 30'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.ensureVisible(find.widgetWithText(ListTile, 'API Market 30'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'API Market 30'));
    await tester.pumpAndSettle();
    expect(tester.widget<BThereSelectorField<int>>(field).initialValue, 30);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
