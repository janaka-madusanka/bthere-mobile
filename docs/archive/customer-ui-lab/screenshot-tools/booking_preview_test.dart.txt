import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';

import '../test/booking_fixture.dart';
import '../test/customer_booking_widget_test.dart'
    show openBooking, activeJourney;

void main() {
  testWidgets('preview documented booking stages with synthetic data', (
    tester,
  ) async {
    debugDisableShadows = false;
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
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = BookingFixture();
    f.contextBody = contextJson(
      fields: [
        {
          ...fieldJson(id: 20, code: 'WARD', type: 'TEXT'),
          'label': 'Ward number',
        },
        {
          ...fieldJson(id: 21, code: 'BED', type: 'TEXT'),
          'label': 'Bed number',
        },
      ],
    );
    f.contextBody['providerFilters'] = [
      {
        'fieldId': 25,
        'label': 'Gender preference',
        'fieldType': 'SELECT',
        'filterOperator': 'IN',
        'options': [
          {'value': 'MALE', 'label': 'Male'},
          {'value': 'FEMALE', 'label': 'Female'},
        ],
      },
    ];
    addTearDown(f.f.dispose);
    await openBooking(tester, f);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/booking-previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    final c = activeJourney(tester);
    c.edit(() {
      c.providerFilters[25] = ['FEMALE'];
      c.languages.add('ENGLISH');
      c.skills.add(10);
      c.start = '2030-01-07T08:00:00';
      c.end = '2030-01-07T10:00:00';
      c.point = const GeoPoint(6.9271, 79.8612);
      c.address = 'Test service address';
    });
    await capture('details');
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-start-time')),
    );
    await capture('details-schedule');
    await tester.runAsync(() => c.nextServiceDetails());
    await capture('service-details');
    final searching = c.search();
    await tester.pumpAndSettle();
    await searching;
    await capture('results');
    c.select(c.candidates.single);
    c.review();
    await capture('review');
    final submitting = c.submit();
    await tester.pumpAndSettle();
    await submitting;
    await capture('created');
    debugDisableShadows = true;
    expect(tester.takeException(), isNull);
  });
}
