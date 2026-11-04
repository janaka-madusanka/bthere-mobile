import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/booking_fixture.dart';

void main() {
  testWidgets('calendar style, cancellation and compact date selection', (
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
    final f = BookingFixture();
    await tester.runAsync(f.start);
    addTearDown(f.dispose);
    f.input();
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CustomerTheme.authentication(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    BookingSchedulePicker(controller: f.journey)
                        .showCalendar(context),
                child: const Text('Open calendar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Choose service date'), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('booking-calendar-dialog')),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-previews/calendar-popup.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(f.journey.start, '2030-01-07T08:00:00');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('20'));
    await tester.ensureVisible(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(f.journey.start, '2030-01-20T08:00:00');
    expect(f.journey.end, '2030-01-20T10:00:00');
    expect(tester.takeException(), isNull);
  });
}
