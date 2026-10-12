import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';

import '../test/email_registration_onboarding_test.dart' as flow;
import '../test/support/fake_session_storage.dart';

void main() {
  testWidgets('render Provider Details for visual review', (tester) async {
    await tester.runAsync(() async {
      const sdkPath = String.fromEnvironment('FLUTTER_SDK');
      if (sdkPath.isEmpty) {
        throw StateError('Pass --dart-define=FLUTTER_SDK=<Flutter SDK path>.');
      }
      final fonts = Directory('$sdkPath/bin/cache/artifacts/material_fonts');
      final loader = FontLoader('Nunito');
      for (final name in [
        'roboto-regular.ttf',
        'roboto-bold.ttf',
        'roboto-medium.ttf',
      ]) {
        loader.addFont(
          File('${fonts.path}/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File('${fonts.path}/materialicons-regular.otf')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
      await icons.load();
    });
    tester.view.physicalSize = const ui.Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = flow.OnboardingFixture();
    addTearDown(fixture.dispose);
    fixture.storage.session = testSession();
    fixture.adapter.completion['profileCompleted'] = false;
    final container = fixture.container;
    const previewKey = ValueKey('details-preview-root');
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const BThereProviderApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(previewKey),
      );
      boundary.markNeedsPaint();
      await tester.pump();
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/provider-details-previews/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await capture('provider-details');
    final gender = find.byKey(const ValueKey('profile-gender'));
    await tester.ensureVisible(gender);
    await tester.tap(gender);
    await tester.pumpAndSettle();
    await capture('gender-sheet');
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await tester.tap(gender);
    await tester.pumpAndSettle();
    await capture('gender-selected-sheet');
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    final market = find.byKey(const ValueKey('profile-market'));
    await tester.ensureVisible(market);
    await tester.tap(market);
    await tester.pumpAndSettle();
    await capture('market-sheet');
    await tester.tap(find.text('API market').last);
    await tester.pumpAndSettle();
    await tester.tap(market);
    await tester.pumpAndSettle();
    await capture('market-selected-sheet');
    await tester.tap(find.text('API market').last);
    await tester.pumpAndSettle();
  });
}
