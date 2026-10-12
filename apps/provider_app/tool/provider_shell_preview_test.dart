import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';

import 'package:flutter/material.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/app/presentation/provider_tabs.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:bthere_common/bthere_common.dart';

import '../test/support/fake_service_repository.dart';

import '../test/service_first_test.dart' show ServiceFixture;
import '../test/provider_account_test.dart' show accountSession;

void main() {
  testWidgets('render authenticated Home and Services for visual review', (
    tester,
  ) async {
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
    final fixture = ServiceFixture(
      existing: true,
      step: 'COMPLETE_SERVICE_REQUIREMENTS',
    );
    fixture.storage.session = accountSession();
    fixture.services.catalog = Success(
      parseActiveProviderServices([
        serviceJson(),
        serviceJson(id: 9, name: 'Other service'),
        serviceJson(id: 20, name: 'A longer preview service name for wrapping'),
      ]),
    );
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
    Future<void> capture(String name, {bool settle = true}) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(previewKey),
      );
      boundary.markNeedsPaint();
      await tester.pump();
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/provider-shell-previews/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
    }

    final router = container.read(appRouterProvider);
    await capture('home-widget-large');
    router.go(AppRoutes.services);
    await tester.pumpAndSettle();
    await capture('services-grid-large');
    for (final tab in ProviderTab.values.where(
      (tab) => tab.description != null,
    )) {
      router.go(tab.path);
      await tester.pumpAndSettle();
      await capture('${tab.label.toLowerCase()}-placeholder');
    }
    router.go(AppRoutes.services);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const ui.Size(320, 568);
    await tester.pumpAndSettle();
    await capture('services-grid-small');
    await tester.ensureVisible(find.byKey(const ValueKey('main-service-20')));
    await tester.pumpAndSettle();
    await capture('services-grid-small-last-row');
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    await capture('home-widget-small');
    tester.view.physicalSize = const ui.Size(430, 1100);
    router.go(AppRoutes.services);
    await tester.pumpAndSettle();
    fixture.services.pendingLoad =
        Completer<Result<List<ProviderServiceType>>>();
    await tester.tap(find.byKey(const ValueKey('refresh-services')));
    await tester.pump();
    await capture('services-loading', settle: false);
    fixture.services.pendingLoad!.complete(fixture.services.catalog);
    await tester.pumpAndSettle();
    router.go(AppRoutes.account);
    await tester.pumpAndSettle();
    await capture('profile-page');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();
    await capture('profile-page-actions');
  });
}
