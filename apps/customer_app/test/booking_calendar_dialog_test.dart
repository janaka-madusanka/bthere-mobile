import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_calendar_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final input in [false, true]) {
    testWidgets(
      'compact calendar selects the last day of a six-week month ${input ? 'by input' : 'from the grid'}',
      (tester) async {
        DateTime? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: CustomerTheme.authentication(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => selected = await showDialog<DateTime>(
                    context: context,
                    builder: (_) => BookingCalendarDialog(
                      initialDate: DateTime(2026, 8, 15),
                      firstDate: DateTime(2026, 1, 1),
                      lastDate: DateTime(2028, 12, 31),
                      currentDate: DateTime(2026, 8, 1),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (input) {
          await tester.tap(find.byTooltip('Enter date'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), 'bad');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.byType(BookingCalendarDialog), findsOneWidget);
          final context = tester.element(find.byType(InputDatePickerFormField));
          final date = MaterialLocalizations.of(context)
              .formatCompactDate(DateTime(2026, 8, 31));
          await tester.enterText(find.byType(TextFormField), date);
        } else {
          await tester.tap(find.text('31'));
        }
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, 8, 31));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
