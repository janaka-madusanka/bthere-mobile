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
  testWidgets('preview map and provider selection panel', (tester) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
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
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = BookingFixture();
    addTearDown(f.f.dispose);
    const names = [
      'Nethmi Perera',
      'Kasun Fernando',
      'Tharushi Silva',
      'Dilshan Wickramasinghe',
      'Sewwandi Rajapaksha',
    ];
    f.candidateRows = [
      for (var i = 0; i < 5; i++)
        {
          ...candidateJson(id: 15 + i),
          'displayName': names[i],
          'averageRating': 4.9 - i * .1,
          'totalRatings': 124 - i * 12,
        },
    ];
    await openBooking(tester, f);
    await advanceToServiceDetails(tester);
    final c = activeJourney(tester);
    await tester.runAsync(c.search);
    await tester.pumpAndSettle();
    c.select(c.candidates.first);
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/booking-previews/provider-results.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    debugDisableShadows = true;
  });
}
