import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_saved_cards_dialog.dart';
import 'package:customer_app/features/wallet/data/customer_wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreviewCards extends Fake implements CustomerWalletRepository {
  @override
  Future<WalletSnapshot> load() async => WalletSnapshot(
    null,
    {},
    [
      {
        'methodId': 1,
        'type': 'CARD',
        'status': 'VERIFIED_MOCK',
        'brand': 'VISA',
        'displayLabel': 'Test Visa 4242',
        'expiryMonth': 12,
        'expiryYear': 2028,
        'isDefault': true,
      },
      {
        'methodId': 2,
        'type': 'CARD',
        'status': 'VERIFIED_MOCK',
        'brand': 'MASTERCARD',
        'displayLabel': 'Test Mastercard 5678',
        'expiryMonth': 8,
        'expiryYear': 2029,
      },
      {
        'methodId': 3,
        'type': 'CARD',
        'status': 'VERIFIED_MOCK',
        'brand': 'VISA',
        'displayLabel': 'Test Visa 9012',
        'expiryMonth': 11,
        'expiryYear': 2029,
      },
    ],
    WalletPage([], 0, true),
    true,
  );
}

void main() {
  testWidgets('preview saved cards dialog', (tester) async {
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
    final previewKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          theme: CustomerTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: const Color(0xFFE5F3F3),
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BookingSavedCardsDialog(
                      repository: _PreviewCards(),
                      onAddCard: () async {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-saved-card-1')));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(previewKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/booking-previews/saved-cards.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
