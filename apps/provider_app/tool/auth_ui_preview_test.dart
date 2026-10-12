import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';

import '../test/email_auth_screen_test.dart' as flow;
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_session_storage.dart';

void main() {
  testWidgets('render real auth screens for visual review', (tester) async {
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
    final container = await flow.pumpAuth(
      tester,
      FakeAuthRepository(),
      FakeSessionStorage(),
    );
    const previewKey = ValueKey('auth-preview-root');
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
        final output = File('build/auth-ui-previews/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await flow.openRegistration(tester);
    await capture('create-account');
    final signIn = find.byKey(const ValueKey('auth-sign-in-tab'));
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    await capture('sign-in');
  });
}
