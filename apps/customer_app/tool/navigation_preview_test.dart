import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/discovery/presentation/customer_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render bottom navigation reference preview', (tester) async {
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
    tester.view.physicalSize = const Size(430, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const key = ValueKey('navigation-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: CustomerTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
            child: Scaffold(
              backgroundColor: Color(0xFF00666B),
              bottomNavigationBar: CustomerBottomNavigation(
                selected: CustomerNavigationTab.home,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/navigation-previews/bottom-navigation.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  });
}
