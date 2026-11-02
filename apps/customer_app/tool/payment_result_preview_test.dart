import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_payment_result_screen.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets('preview payment ${success ? 'success' : 'failure'}', (
      tester,
    ) async {
      debugDisableShadows = false;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
              'Public Sans',
            )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf')))
            .load();
        const sdk = String.fromEnvironment('FLUTTER_SDK');
        await (FontLoader('MaterialIcons')..addFont(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: CustomerTheme.light(),
          home: BookingPaymentResultScreen(
            success: success,
            subtitle: success ? 'Your request has been confirmed.' : 'We couldn’t process your payment at the moment. Please try again.',
            reason: 'Insufficient available wallet balance',
            onRetry: () {},
            onDifferentMethod: () {},
            onHome: () {},
            onBooking: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      {
        await tester.runAsync(
          () => precacheImage(
            AssetImage(
              'assets/illustrations/payment/payment_${success ? 'success' : 'failed'}.png',
            ),
            tester.element(find.byType(BookingPaymentResultScreen)),
          ),
        );
        await tester.pumpAndSettle();
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/booking-previews/payment-${success ? 'success' : 'failed'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      debugDisableShadows = true;
    });
  }
}
