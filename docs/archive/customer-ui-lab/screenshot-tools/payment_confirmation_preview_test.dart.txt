import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_request_receipt.dart';
import 'package:customer_app/features/booking/presentation/booking_payment_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pending = bool.fromEnvironment('BTHERE_RENDER_PENDING');
  const confirmed = bool.fromEnvironment('BTHERE_RENDER_CONFIRMED');
  const expired = bool.fromEnvironment('BTHERE_RENDER_EXPIRED');
  const cancelled = bool.fromEnvironment('BTHERE_RENDER_CANCELLED');
  testWidgets('render payment confirmation with sample data', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
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
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: CustomerTheme.light(),
          home: BookingPaymentPage(
            onBack: () {},
            child: BookingRequestReceipt(
              request: {
                'requestId': 501,
                'status': cancelled
                    ? 'CANCELLED'
                    : expired
                    ? 'EXPIRED'
                    : confirmed
                    ? 'CONFIRMED'
                    : pending
                    ? 'PAYMENT_PENDING'
                    : 'AWAITING_CUSTOMER_CONFIRMATION',
                'paymentMethod': 'WALLET',
                'paymentStatus': confirmed ? 'RESERVED' : 'PENDING',
                'expectedAmount': 42000,
                'currencyCode': 'LKR',
              },
              onRefresh: () {},
              onConfirmWallet: () {},
              onHome: () {},
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(BookingRequestReceipt));
      for (final asset in [
        'secure_payment_mascot.png',
        'payment_amount_banner.png',
        'secure_payment_card.png',
      ]) {
        await precacheImage(
          AssetImage('assets/illustrations/payment/$asset'),
          context,
        );
      }
      if (confirmed) {
        await precacheImage(
          const AssetImage(
            'assets/illustrations/booking/booking_confirmed_mascot.png',
          ),
          context,
        );
      }
    });
    if (expired) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(
            'assets/illustrations/booking/request_expired_mascot.png',
          ),
          tester.element(find.byType(BookingRequestReceipt)),
        ),
      );
    }
    if (cancelled) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(
            'assets/illustrations/booking/request_cancelled_mascot.png',
          ),
          tester.element(find.byType(BookingRequestReceipt)),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'build/booking-previews/${cancelled
            ? 'request-cancelled'
            : expired
            ? 'request-expired'
            : confirmed
            ? 'booking-confirmed'
            : pending
            ? 'payment-pending'
            : 'payment-confirmation'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  });
}
