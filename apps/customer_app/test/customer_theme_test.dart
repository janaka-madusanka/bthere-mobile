import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:customer_app/app/customer_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Customer theme follows designer roles without changing shared Provider theme', () {
    final theme = CustomerTheme.light();
    expect(theme.textTheme.headlineLarge!.fontFamily, 'Public Sans');
    expect(theme.textTheme.headlineLarge!.fontSize, 24);
    expect(theme.textTheme.headlineLarge!.height, 32 / 24);
    expect(theme.textTheme.titleLarge!.fontSize, 18);
    expect(theme.textTheme.bodyMedium!.fontSize, 14);
    expect(theme.textTheme.labelMedium!.fontSize, 12);
    expect(theme.textTheme.labelSmall!.fontSize, 10);
    expect(theme.colorScheme.primary, const Color(0xFF008F95));
    expect(theme.colorScheme.onSurface, const Color(0xFF0B3037));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFB));
    expect(BThereTheme.light().textTheme.bodyMedium!.fontFamily, 'Nunito');
  });
  testWidgets('shared controls inherit Customer font and button sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CustomerTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              BThereButton(label: 'Continue', onPressed: () {}),
              const BThereTextField(
                label: 'First name',
                labelPlacement: BThereFieldLabelPlacement.above,
              ),
            ],
          ),
        ),
      ),
    );
    final label = tester.element(find.text('Continue'));
    expect(DefaultTextStyle.of(label).style.fontFamily, 'Public Sans');
    expect(DefaultTextStyle.of(label).style.fontSize, 14);
    expect(DefaultTextStyle.of(label).style.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      inInclusiveRange(48, 52),
    );
    final field = tester.element(find.text('First name'));
    expect(DefaultTextStyle.of(field).style.fontFamily, 'Public Sans');
    expect(tester.takeException(), isNull);
  });
}
