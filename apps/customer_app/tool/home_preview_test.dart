import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/presentation/customer_bookings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/customer_auth_test.dart' show Fixture;
import '../test/customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets('preview home with supplied service artwork', (tester) async {
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
    final f = Fixture();
    addTearDown(f.dispose);
    await marketEntry(tester, f);
    await continueMarket(tester);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/illustrations/get_a_service.png'),
        tester.element(find.byKey(const ValueKey('customer-find-help'))),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-previews/customer-home.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    f.adapter.extraHandler = (request) async =>
        request.uri.path.endsWith('/customers/me/bookings')
        ? ResponseBody.fromString(
            jsonEncode([
              {
                'jobId': 101,
                'optionId': 12,
                'paymentMethod': 'WALLET',
                'currencyCode': 'LKR',
                'expectedAmount': 3500,
                'serviceTypeId': 1,
                'startDatetime': '2026-11-05T09:00:00',
                'status': 'CONFIRMED',
                'paymentStatus': 'PAID',
              },
              {
                'jobId': 102,
                'optionId': 12,
                'paymentMethod': 'WALLET',
                'currencyCode': 'LKR',
                'expectedAmount': 3500,
                'serviceTypeId': 1,
                'startDatetime': '2026-11-02T09:00:00',
                'status': 'COMPLETED',
                'paymentStatus': 'PAID',
              },
            ]),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          )
        : null;
    ProviderScope.containerOf(
      tester.element(find.byType(CustomerRecentBookings)),
    ).invalidate(customerBookingHistoryProvider(12));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('customer-booking-101')), findsOneWidget);
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('build/home-previews/customer-home-recent.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
