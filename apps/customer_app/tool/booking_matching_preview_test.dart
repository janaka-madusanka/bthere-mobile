import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/customer_theme.dart';
import 'package:customer_app/features/booking/presentation/booking_request_progress_screen.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';

import '../test/booking_fixture.dart';

void main() {
  for (final matching in [true, false]) {
    testWidgets('preview ${matching ? 'matching' : 'accepted'} request', (
      tester,
    ) async {
      debugDisableShadows = false;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = BookingFixture();
      addTearDown(f.dispose);
      await tester.runAsync(() async {
        await f.start();
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
      final c = f.journey;
      c.candidates.add(ProviderCandidate(candidateJson()));
      c.created = {
        ...f.requestViewBody,
        'status': matching ? 'MATCHING' : 'AWAITING_CUSTOMER_CONFIRMATION',
        'providerId': matching ? null : 15,
        'confirmationExpiresAt': c
            .now()
            .add(const Duration(minutes: 2))
            .toIso8601String(),
        'paymentMethod': 'WALLET',
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: CustomerTheme.light(),
          home: BookingRequestProgressScreen(
            controller: c,
            onCancel: () {},
            onDetails: () {},
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          AssetImage(
            'assets/illustrations/booking/${matching ? 'finding_provider' : 'provider_accepted'}.png',
          ),
          tester.element(find.byType(BookingRequestProgressScreen)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/booking-previews/${matching ? 'finding-provider' : 'provider-accepted'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      debugDisableShadows = true;
    });
  }
}
