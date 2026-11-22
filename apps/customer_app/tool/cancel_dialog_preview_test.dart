import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_cancel_request_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cancel dialog preview and compact large text', (tester) async {
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
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const BookingCancelRequestDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byType(BookingCancelRequestDialog),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-previews/cancel-dialog.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-keep-request')),
    );
    await tester.tap(find.byKey(const ValueKey('booking-keep-request')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCancelRequestDialog), findsNothing);
  });
}
