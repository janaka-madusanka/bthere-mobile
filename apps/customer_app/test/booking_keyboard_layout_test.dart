import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_booking_widget_test.dart'
    show openBooking, advanceToServiceDetails, activeJourney;

void main() {
  for (final screenHeight in [932.0, 568.0]) {
    testWidgets(
      'booking fields stay reachable with keyboard at height $screenHeight',
      (tester) async {
        tester.view.physicalSize = Size(430, screenHeight);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final f = BookingFixture();
        addTearDown(f.f.dispose);
        f.contextBody = contextJson(
          fields: [
            {...fieldJson(id: 20, code: 'PERSON'), 'label': 'Person name'},
            {...fieldJson(id: 21, code: 'HOSPITAL'), 'label': 'Hospital name'},
            {...fieldJson(id: 22, code: 'WARD'), 'label': 'Ward number'},
          ],
        );
        await openBooking(tester, f);
        await advanceToServiceDetails(tester);
        final c = activeJourney(tester);
        final location = c.point;
        final sheet = tester.widget<DraggableScrollableSheet>(
          find.byKey(const ValueKey('booking-details-sheet')),
        );
        final oldExtent = sheet.controller!.size;
        final field = find.byKey(const ValueKey('booking-input-field-22'));
        await tester.ensureVisible(field);
        await tester.enterText(field, 'A32');
        tester.view.viewInsets = const FakeViewPadding(bottom: 360);
        await tester.pumpAndSettle();
        final keyboardSheet = tester.widget<DraggableScrollableSheet>(
          find.byKey(const ValueKey('booking-details-sheet')),
        );
        expect(keyboardSheet.minChildSize, 1);
        expect(keyboardSheet.maxChildSize, 1);
        expect(keyboardSheet.controller!.size, 1);
        expect(find.text('Done'), findsNothing);
        expect(
          find.byKey(const ValueKey('booking-availability-count')),
          findsNothing,
        );
        expect(find.byTooltip('Use current location'), findsNothing);
        expect(c.stage, BookingStage.serviceDetails);
        expect(c.answers['WARD'], 'A32');
        expect(c.point, same(location));
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final rect = tester.getRect(editable);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screenHeight - 360));
        if (screenHeight > 600) {
          expect(
            rect.bottom,
            lessThan(
              tester
                  .getTopLeft(
                    find.byKey(const ValueKey('booking-details-footer')),
                  )
                  .dy,
            ),
          );
        }
        expect(tester.takeException(), isNull);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.hasPrimaryFocus == true &&
              FocusManager.instance.primaryFocus?.context
                      ?.findAncestorStateOfType<EditableTextState>() !=
                  null,
          isFalse,
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('booking-keyboard-toolbar')),
          findsNothing,
        );
        expect(c.answers['WARD'], 'A32');
        expect(sheet.controller!.size, closeTo(oldExtent, .03));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
