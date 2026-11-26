import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/booking_fixture.dart';
import '../test/customer_booking_widget_test.dart'
    show openBooking, advanceToServiceDetails, activeJourney;

void main() {
  testWidgets('preview map-based booking review with synthetic data', (
    tester,
  ) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final f = BookingFixture();
    f.contextBody = contextJson(
      methods: ['CARD', 'WALLET', 'CASH'],
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
    addTearDown(f.f.dispose);
    await openBooking(tester, f);
    await advanceToServiceDetails(tester);
    final c = activeJourney(tester);
    c.answers.addAll({'WARD': 'Ward 12', 'BED': 'Bed 05'});
    c.method = 'CARD';
    c.review();
    await tester.runAsync(c.previewQuote);
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/booking-previews/review-map.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    debugDisableShadows = true;
  });
}
