import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/customer_auth_test.dart' show Fixture, serviceJson, optionJson;
import '../test/customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'service category reference layout, search, options and large text',
    (tester) async {
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
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = Fixture();
      addTearDown(f.dispose);
      Map<String, Object?> category(int id, String name, String description) {
        final value = serviceJson(id: id, name: name);
        return {
          ...value,
          'service': {...value['service'] as Map, 'description': description},
        };
      }

      f.adapter.serviceBodies[1] = [
        category(3, 'Caregiver', 'Reliable hospital and home assistance'),
        category(4, 'Home Services', 'Everyday help for home needs'),
        category(5, 'Pet Care', 'Trusted care for your pets'),
      ];
      f.adapter.optionBodies['1/3'] = [
        optionJson(name: 'Hospital Care'),
        optionJson(id: 13, name: 'Home Care', order: 2),
        optionJson(id: 14, name: 'Care Ride', order: 3),
      ];
      await marketEntry(tester, f);
      await continueMarket(tester);
      final categoryCard = find.byKey(const ValueKey('customer-service-3'));
      await tester.ensureVisible(categoryCard);
      await tester.tap(categoryCard);
      await tester.pumpAndSettle();
      expect(find.text('Hospital Care'), findsOneWidget);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/home-previews/services-tab.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.enterText(
        find.byKey(const ValueKey('customer-service-search')),
        'nothing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching services'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear service search'));
      await tester.pumpAndSettle();
      expect(find.text('Hospital Care'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final option = find.byKey(const ValueKey('customer-option-12'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('Continue with this service'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
