import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/wallet/domain/card_validation.dart';
import 'package:customer_app/features/wallet/presentation/add_test_card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openCardDialog(
  WidgetTester tester,
  Future<bool> Function() onAdd,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CustomerTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AddTestCardDialog(
                now: () => DateTime(2030, 1, 31),
                onAdd: onAdd,
              ),
            ),
            child: const Text('Open card'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open card'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'correcting a rejected number clears the old error and accepts the spaced test card',
    (tester) async {
      var calls = 0;
      await openCardDialog(tester, () async {
        calls++;
        return true;
      });
      await tester.enterText(
        find.byKey(const ValueKey('cardholder-name')),
        'Janaka',
      );
      await tester.enterText(
        find.byKey(const ValueKey('card-number')),
        '4111111111111111',
      );
      await tester.enterText(find.byKey(const ValueKey('card-expiry')), '1235');
      await tester.enterText(find.byKey(const ValueKey('card-cvv')), '123');
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-test-card')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-test-card')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use test number'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('card-number')),
        '4242 4242 4242 4242',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Use test number'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-test-card')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-test-card')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AddTestCardDialog), findsNothing);
    },
  );
  test(
    'card brand recognizes partial prefixes without claiming number validity',
    () {
      expect(CardValidation.brand('4'), CardBrand.visa);
      expect(CardValidation.brand('51'), CardBrand.mastercard);
      expect(CardValidation.brand('55'), CardBrand.mastercard);
      expect(CardValidation.brand('2221'), CardBrand.mastercard);
      expect(CardValidation.brand('2720'), CardBrand.mastercard);
      for (final prefix in ['', '2', '2220', '2721', '56', '37']) {
        expect(CardValidation.brand(prefix), isNull);
      }
      expect(CardValidation.number('4'), isNotNull);
    },
  );
  testWidgets(
    'number field updates Visa and Mastercard logos while typing and hides unknown brand',
    (tester) async {
      await openCardDialog(tester, () async => true);
      final number = find.byKey(const ValueKey('card-number'));
      expect(find.byKey(const ValueKey('card-brand-visa')), findsNothing);
      await tester.enterText(number, '4');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-brand-visa')), findsOneWidget);
      expect(find.bySemanticsLabel('Visa'), findsOneWidget);
      await tester.enterText(number, '55');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-brand-visa')), findsNothing);
      expect(
        find.byKey(const ValueKey('card-brand-mastercard')),
        findsOneWidget,
      );
      await tester.enterText(number, '2221');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('card-brand-mastercard')),
        findsOneWidget,
      );
      await tester.enterText(number, '2721');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-brand-mastercard')), findsNothing);
      expect(find.text('Test mode'), findsOneWidget);
      expect(find.textContaining('Test details are not sent'), findsNothing);
    },
  );
  test(
    'card number checks format, supported brands, BIN boundaries and Luhn',
    () {
      expect(CardValidation.number('4242 4242 4242 4242'), isNull);
      expect(CardValidation.number('5555-5555-5555-4444'), isNull);
      expect(CardValidation.number('2221000000000009'), isNull);
      expect(CardValidation.number('2720990000000007'), isNull);
      for (final value in [
        '',
        '0000000000000000',
        '4242424242424241',
        '4242x424242424242',
        '424242424242424',
        '378282246310005',
      ]) {
        expect(CardValidation.number(value), isNotNull, reason: value);
      }
    },
  );
  test('expiry rejects expired dates and invalid months but includes current month', () {
    final now = DateTime(2030, 1, 31, 23, 59);
    for (final value in ['', '1/30', '00/35', '13/35', '12/29', '12/2029']) {
      expect(CardValidation.expiry(value, now), isNotNull, reason: value);
    }
    expect(CardValidation.expiry('01/30', now), isNull);
    expect(CardValidation.expiry('12/35', now), isNull);
    expect(CardValidation.expiry('01/30', DateTime(2030, 2, 1)), isNotNull);
  });
  test(
    'cardholder names support Unicode and security codes retain leading zeros',
    () {
      for (final name in ['Janaka', 'O’Neil-Silva', 'සිල්වා', 'தமிழ்']) {
        expect(CardValidation.name(name), isNull);
      }
      for (final name in ['', '  ', '123', 'User 123', '<script>', '---']) {
        expect(CardValidation.name(name), isNotNull);
      }
      expect(CardValidation.cvv('001'), isNull);
      for (final cvv in ['', '12', '1234', '1a2', ' 123']) {
        expect(CardValidation.cvv(cvv), isNotNull);
      }
    },
  );
  testWidgets('invalid or non-test card never reaches setup callback', (
    tester,
  ) async {
    var calls = 0;
    await openCardDialog(tester, () async {
      calls++;
      return true;
    });
    await tester.ensureVisible(find.byKey(const ValueKey('submit-test-card')));
    await tester.tap(find.byKey(const ValueKey('submit-test-card')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the name on the card.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('cardholder-name')),
      'Test Customer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('card-number')),
      '4111111111111111',
    );
    await tester.enterText(find.byKey(const ValueKey('card-expiry')), '1229');
    await tester.enterText(find.byKey(const ValueKey('card-cvv')), '12');
    await tester.ensureVisible(find.byKey(const ValueKey('submit-test-card')));
    await tester.tap(find.byKey(const ValueKey('submit-test-card')));
    await tester.pumpAndSettle();
    expect(find.text('This card has expired.'), findsOneWidget);
    expect(
      find.text(
        'Use test number 4242 4242 4242 4242. Real cards cannot be linked yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enter the 3-digit security code.'), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets(
    'valid test details submit once and are not retained on reopening',
    (tester) async {
      var calls = 0;
      Future<bool> add() async {
        calls++;
        return true;
      }

      await openCardDialog(tester, add);
      await tester.enterText(
        find.byKey(const ValueKey('cardholder-name')),
        'Test Customer',
      );
      await tester.enterText(
        find.byKey(const ValueKey('card-number')),
        '4242424242424242',
      );
      await tester.enterText(find.byKey(const ValueKey('card-expiry')), '1235');
      await tester.enterText(find.byKey(const ValueKey('card-cvv')), '001');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('card-number')))
            .controller!
            .text,
        '4242 4242 4242 4242',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('card-expiry')))
            .controller!
            .text,
        '12/35',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-test-card')),
      );
      await tester.tap(find.byKey(const ValueKey('submit-test-card')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AddTestCardDialog), findsNothing);
      await tester.tap(find.text('Open card'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('card-number')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('card-cvv')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  testWidgets('dialog remains usable with keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCardDialog(tester, () async => true);
    await tester.ensureVisible(find.byKey(const ValueKey('submit-test-card')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
