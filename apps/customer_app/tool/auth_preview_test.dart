import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/customer_config.dart';
import 'package:customer_app/features/auth/presentation/customer_verification_page.dart';
import 'package:customer_app/features/auth/presentation/customer_verification_success_screen.dart';
import 'package:customer_app/app/customer_providers.dart';
import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';

import '../test/customer_auth_test.dart'
    show Fixture, clock, marketJson, serviceJson, optionJson;

void main() {
  testWidgets(
    'render Customer sign-in and registration using real branded assets',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await tester.runAsync(() async {
        final loader = FontLoader('Public Sans')
          ..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'));
        await loader.load();
        const sdk = String.fromEnvironment('FLUTTER_SDK');
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        await icons.load();
      });
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = ValueKey('customer-auth-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              customerConfigProvider.overrideWithValue(
                CustomerConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
              ),
              customerClockProvider.overrideWithValue(() => clock),
              customerSessionStorageProvider.overrideWithValue(f.storage),
              customerApiClientProvider.overrideWithValue(f.client),
              customerMarketSelectionStoreProvider.overrideWithValue(
                f.marketStore,
              ),
            ],
            child: const CustomerApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        void repaint(RenderObject node) {
          node.markNeedsPaint();
          node.visitChildren(repaint);
        }

        repaint(boundary);
        await tester.pump();
        await tester.runAsync(() async {
          final picture = await boundary.toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File('build/auth-previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }

      await capture('customer-sign-in');
      await tester.tap(find.byKey(const ValueKey('customer-register-tab')));
      await tester.pumpAndSettle();
      await capture('customer-register');
      await tester.tap(find.byKey(const ValueKey('customer-login-tab')));
      await tester.pumpAndSettle();
      await capture('customer-sign-in');
      await tester.tap(find.byKey(const ValueKey('customer-register-tab')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.physicalSize = const Size(430, 1100);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-login-tab')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-login-tab')));
      await tester.pumpAndSettle();
      f.adapter.profileStatus = 404;
      await tester.enterText(
        find.byKey(const ValueKey('customer-identifier')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-password')),
        'password-123',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      await capture('customer-profile');
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-profile-save')),
      );
      await tester.pumpAndSettle();
      await capture('customer-profile-bottom');
      final code = TextEditingController();
      addTearDown(code.dispose);
      tester.view.physicalSize = const Size(390, 844);
      for (final phone in [false, true]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: CustomerVerificationPage(
                formKey: GlobalKey<FormState>(),
                otp: code,
                phone: phone,
                destination: phone ? '+94771234567' : 'customer@example.com',
                remaining: 30,
                busy: false,
                error: null,
                onSubmit: () {},
                onResend: () {},
                onChangeDestination: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(
          phone ? 'customer-phone-verification' : 'customer-email-verification',
        );
      }

      for (final phone in [false, true]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: CustomerVerificationSuccessPage(
                phone: phone,
                onContinue: () {},
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await capture(
          phone ? 'customer-phone-verified' : 'customer-email-verified',
        );
      }

      f.adapter.profileStatus = 200;
      f.adapter.marketsBody = [marketJson()];
      f.adapter.serviceBodies[1] = [
        serviceJson(id: 3, name: 'Caregiving'),
        serviceJson(id: 4, name: 'Home Services'),
        serviceJson(id: 5, name: 'Pet Care'),
        serviceJson(id: 6, name: 'Childcare'),
        serviceJson(id: 7, name: 'Handyman'),
        serviceJson(id: 8, name: 'Vehicle Services'),
        serviceJson(id: 9, name: 'Errands & Delivery'),
        serviceJson(id: 10, name: 'Wellness & Lifestyle'),
      ];
      f.adapter.optionBodies['1/3'] = [
        for (final (i, name) in [
          'Elderly Care',
          'Patient Care',
          'Post-Surgery Care',
          'Disability Support',
          'Companionship',
          'Personal Care Assistance',
        ].indexed)
          optionJson(id: i + 12, name: name, order: i),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              customerConfigProvider.overrideWithValue(
                CustomerConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
              ),
              customerClockProvider.overrideWithValue(() => clock),
              customerSessionStorageProvider.overrideWithValue(f.storage),
              customerApiClientProvider.overrideWithValue(f.client),
              customerMarketSelectionStoreProvider.overrideWithValue(
                f.marketStore,
              ),
            ],
            child: const CustomerApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('customer-market-single');
      f.adapter.marketsBody = [
        marketJson(),
        marketJson(id: 2, name: 'United States', country: 'US'),
      ];
      ProviderScope.containerOf(tester.element(find.byType(CustomerApp)))
          .read(customerDiscoveryProvider)
          .loadMarkets();
      await tester.pumpAndSettle();
      await capture('customer-market-selection');
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-market-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-market-continue')));
      await tester.pumpAndSettle();
      await capture('customer-home');
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-service-8')),
      );
      await tester.pumpAndSettle();
      await capture('customer-home-services');
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-service-3')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-service-3')));
      await tester.pumpAndSettle();
      await capture('customer-services-expanded');
    },
  );
}
