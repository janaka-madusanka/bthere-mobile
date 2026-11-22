import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_booking_progress_widget_test.dart' show openProgress;

void main() {
  testWidgets(
    'completion requires explicit confirmation and stays on completed details at large text',
    (tester) async {
      final f = await openProgress(tester);
      expect(
        find.byKey(const ValueKey('booking-confirm-completion')),
        findsNothing,
      );
      f.bookings = [
        {...f.bookings.single, 'status': 'AWAITING_COMPLETION_CONFIRMATION'},
      ];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('booking-confirm-completion'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('completion-confirmation-dialog')),
        findsOneWidget,
      );
      expect(find.text('No additional payment is made.'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/confirm-completion'),
        ),
        isEmpty,
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final submit = find.byKey(
        const ValueKey('completion-confirmation-submit'),
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-confirm-completion')),
        findsNothing,
      );
      expect(
        f.f.adapter.requests.where(
          (r) => r.path.endsWith('/confirm-completion'),
        ),
        hasLength(1),
      );
      expect(
        f.f.adapter.requests.where(
          (r) =>
              r.path.endsWith('/confirm-wallet') || r.path.endsWith('/confirm'),
        ),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'completion rejection remains awaiting with retry and server explanation',
    (tester) async {
      final f = await openProgress(tester);
      f.completionStatus = 409;
      f.bookings = [
        {...f.bookings.single, 'status': 'AWAITING_COMPLETION_CONFIRMATION'},
      ];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('booking-confirm-completion'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('completion-confirmation-submit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Awaiting your confirmation'), findsOneWidget);
      expect(
        find.text('Completion settlement could not be posted'),
        findsOneWidget,
      );
      expect(find.text('Completed'), findsNothing);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
