import 'package:customer_app/debug/booking_ui_lab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final scene in BookingLabScene.values) {
      testWidgets(
        '${scene.id} at $size with large text is scrollable and has no layout errors',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(BookingUiLab(initialScene: scene));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('ui-lab-scale')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('ui-lab-scale')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final patient = find.text('Patient details');
          if (patient.evaluate().isNotEmpty) {
            await tester.ensureVisible(patient);
            await tester.tap(patient);
            await tester.pumpAndSettle();
            expect(find.text('Sample patient'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  for (final action in ['provider', 'rating', 'cancellation', 'code', 'chat']) {
    testWidgets(
      '$action sheet/action works at 320px with 2x text and keyboard inset',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          BookingUiLab(
            initialScene: action == 'rating'
                ? BookingLabScene.completed
                : BookingLabScene.readyCode,
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byKey(const ValueKey('ui-lab-scale')));
          await tester.pumpAndSettle();
        }
        final entry = switch (action) {
          'provider' => find.text('Nimal Perera'),
          'chat' => find.byTooltip('Message provider'),
          'rating' => find.text('Add a Review'),
          'cancellation' => find.byKey(
            const ValueKey('booking-review-cancellation'),
          ),
          _ => find.byKey(const ValueKey('booking-start-code-action')),
        };
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (action == 'cancellation') {
          final reason = find.byKey(const ValueKey('cancellation-reason'));
          await tester.ensureVisible(reason);
          await tester.tap(reason);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Other').last);
          await tester.tap(find.text('Other').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (action == 'rating' ||
            action == 'cancellation' ||
            action == 'chat') {
          final note = find.byType(TextField).last;
          await tester.ensureVisible(note);
          await tester.tap(note);
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
