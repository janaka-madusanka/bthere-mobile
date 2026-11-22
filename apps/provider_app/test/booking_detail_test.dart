import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:bthere_design_system/bthere_design_system.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/bookings/application/booking_controller.dart';
import 'package:provider_app/features/bookings/domain/booking_models.dart';
import 'package:provider_app/features/bookings/presentation/booking_detail_screen.dart';

import 'booking_api_test.dart' show bookingJson;

class DetailBookings extends BookingController {
  DetailBookings(this.status);
  final String status;
  @override
  Future<BookingState> build() async => BookingState(
    bookings: [
      AssignedBooking.fromJson({
        ...bookingJson(
          status: status,
          payment: status == 'CANCELLED' ? 'FAILED' : 'PAID',
        ),
        'startDatetime': '2030-01-02T09:45:00',
        'meetingPointName': 'Colombo General Hospital',
        'answers': {
          'CG_PATIENT_NAME': 'Janaka',
          'CG_CONTACT_PHONE': '075651589',
          'CG_HOSPITAL_NAME': 'General Hospital',
        },
      }),
    ],
  );
}

void main() {
  for (final status in ['CONFIRMED', 'CANCELLED']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('$status booking details at $width', (tester) async {
        tester.view.physicalSize = ui.Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          for (final item in {
            'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
            'Nunito': 'assets/fonts/Nunito.ttf',
          }.entries) {
            await (FontLoader(
              item.key,
            )..addFont(rootBundle.load(item.value))).load();
          }
        });
        final container = ProviderContainer(
          overrides: [
            bookingControllerProvider.overrideWith(
              () => DetailBookings(status),
            ),
          ],
        );
        addTearDown(container.dispose);
        const key = ValueKey('details');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: BThereTheme.light(),
              home: RepaintBoundary(
                key: key,
                child: const BookingDetailScreen(jobId: 70),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Patient Name'), findsOneWidget);
        expect(find.text('Janaka'), findsOneWidget);
        expect(find.textContaining('CG_PATIENT'), findsNothing);
        if (status == 'CANCELLED') {
          expect(find.text('No earnings for this booking'), findsOneWidget);
          expect(find.textContaining("You'll earn"), findsNothing);
          expect(find.text('Enter customer start code'), findsNothing);
        } else {
          await tester.scrollUntilVisible(
            find.text('Enter customer start code'),
            200,
          );
          await tester.ensureVisible(find.text('Enter customer start code'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Enter customer start code'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), '123');
          await tester.tap(find.text('Start service'));
          await tester.pump();
          expect(find.text('Enter exactly four digits'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        if (width == 430) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          await tester.runAsync(() async {
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/booking-previews/details-$status.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}
