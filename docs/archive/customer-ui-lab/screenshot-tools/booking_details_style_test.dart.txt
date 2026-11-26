import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/customer_booking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/booking_fixture.dart' show bookingJson;

void main() {
  testWidgets('booking details reference styling and narrow large-text layout', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader('Public Sans')
            ..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf')))
          .load();
      const sdk = String.fromEnvironment('FLUTTER_SDK');
      await (FontLoader('MaterialIcons')..addFont(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    });
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CustomerTheme.authentication(),
        home: BookingDetailsPage(
          onBack: () {},
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CustomerBookingDetailsView(
              booking: {
                ...bookingJson(id: 16, method: 'WALLET'),
                'status': 'CANCELLED',
                'startDatetime': '2026-11-05T20:45:00',
                'expectedEndDatetime': '2026-11-06T02:45:00',
                'meetingPointName': 'Hospital care location',
                'deliveryMode': 'PROVIDER_TO_CUSTOMER',
                'expectedAmount': 21000,
                'answers': {
                  'PATIENT_NAME': 'Patient name',
                  'CONTACT_PHONE': 'Test contact',
                  'HOSPITAL_NAME': 'Hospital name',
                },
              },
              serviceName: 'Caregiver',
              onBookings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-previews/booking-details.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('View all bookings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
