import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/wallet_fixture.dart';
import '../test/customer_wallet_test.dart' show openWallet;

void main() {
  testWidgets('preview initial wallet content with shared chrome', (
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = WalletFixture();
    f.capabilities['cardLinking'] = true;
    addTearDown(f.f.dispose);
    await openWallet(tester, f);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/home_header_background.png'),
        tester.element(find.byKey(const ValueKey('customer-wallet-balance'))),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/wallet-previews/initial-wallet.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.ensureVisible(find.text('Add new payment method'));
    await tester.tap(find.text('Add new payment method'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('card-number')), '4');
    await tester.pumpAndSettle();
    final dialogBoundary = tester
        .element(find.byType(Dialog))
        .findAncestorRenderObjectOfType<RenderRepaintBoundary>()!;
    await tester.runAsync(() async {
      final picture = await dialogBoundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('build/wallet-previews/add-test-card.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.enterText(find.byKey(const ValueKey('card-number')), '5555');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final picture = await dialogBoundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File('build/wallet-previews/add-card-mastercard.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  });
}
