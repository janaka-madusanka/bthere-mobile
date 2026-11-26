import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/app/widgets/customer_top_bar.dart';
import 'package:customer_app/features/booking/presentation/customer_bookings_screen.dart';
import 'package:customer_app/features/discovery/presentation/customer_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/booking_fixture.dart' show bookingJson;

void main() {
  testWidgets('booking tab compact cards, large text and filters', (
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
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CustomerTheme.authentication(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F9F9),
          bottomNavigationBar: const CustomerBottomNavigation(
            selected: CustomerNavigationTab.opportunities,
          ),
          body: Column(
            children: [
              const CustomerTopBar(),
              Expanded(
                child: CustomerOpportunitiesBody(
                  bookings: [
                    {
                      ...bookingJson(
                        id: 701,
                        method: 'WALLET',
                        payment: 'RESERVED',
                      ),
                      'status': 'CONFIRMED',
                    },
                    {
                      ...bookingJson(
                        id: 702,
                        method: 'WALLET',
                        payment: 'SETTLED',
                      ),
                      'status': 'COMPLETED',
                    },
                    {...bookingJson(id: 703), 'status': 'CANCELLED'},
                    {
                      ...bookingJson(id: 704, method: 'CARD'),
                      'status': 'CANCELLED',
                      'expectedAmount': 42000,
                    },
                    {
                      ...bookingJson(id: 705),
                      'status': 'CANCELLED',
                      'expectedAmount': 21000,
                    },
                  ],
                  serviceNames: const {3: 'Hospital Care'},
                  onRefresh: () async {},
                  onOpen: (row) => selected = row['jobId'] as int,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/home_header_background.png'),
        tester.element(find.byType(CustomerTopBar)),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-previews/booking-tab.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('customer-booking-702'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    expect(selected, 702);
    expect(find.byKey(const ValueKey('customer-booking-701')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
