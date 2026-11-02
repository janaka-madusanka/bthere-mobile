import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';
import 'package:customer_app/features/discovery/data/customer_discovery_repository.dart';
import 'package:customer_app/features/discovery/domain/customer_discovery.dart';
import 'package:customer_app/features/profile/application/customer_profile_controller.dart';
import 'package:customer_app/features/profile/data/customer_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture, marketJson, serviceJson;

Future<void> waitForState(Listenable source, bool Function() ready) async {
  if (ready()) return;
  final completed = Completer<void>();
  void changed() {
    if (ready() && !completed.isCompleted) completed.complete();
  }

  source.addListener(changed);
  try {
    await completed.future.timeout(const Duration(seconds: 10));
  } finally {
    source.removeListener(changed);
  }
}

class DiscoveryFixture {
  final f = Fixture();
  late CustomerProfileController profile;
  late CustomerDiscoveryController discovery;
  Future<void> start() async {
    await f.controller.login('test', 'password');
    profile = CustomerProfileController(
      CustomerProfileRepository(f.service),
      f.controller,
    );
    await waitForState(
      profile,
      () => profile.stage != CustomerProfileStage.loading,
    );
    discovery = CustomerDiscoveryController(
      CustomerDiscoveryRepository(f.service),
      f.controller,
      profile,
      selectionStore: f.marketStore,
    );
    await waitForState(
      discovery,
      () => discovery.marketStage != DiscoveryStage.loading,
    );
  }

  void dispose() {
    discovery.dispose();
    profile.dispose();
    f.dispose();
  }
}

Future<void> marketEntry(WidgetTester tester, Fixture f) async {
  await f.pump(tester);
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
}

Future<void> continueMarket(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('customer-market-continue')),
  );
  await tester.tap(find.byKey(const ValueKey('customer-market-continue')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });
  test(
    'malformed catalog identifies the schema field without backend values',
    () {
      final json = serviceJson();
      (json['access'] as Map)['eligibility'] = 'private backend value';
      expect(
        () => CustomerService.fromJson(json),
        throwsA(
          isA<DiscoveryContractException>()
              .having((error) => error.field, 'field', 'access.eligibility')
              .having(
                (error) => error.toString(),
                'safe description',
                isNot(contains('private backend value')),
              ),
        ),
      );
    },
  );
  test(
    'markets and services use authenticated GET and exact marketId query only',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      final repo = CustomerDiscoveryRepository(f.service);
      expect((await repo.markets()).single.currencyCode, 'LKR');
      expect((await repo.services(1)).single.name, 'Nursing');
      final request = f.adapter.requests.last;
      expect(request.method, 'GET');
      expect(request.uri.queryParameters, {'marketId': '1'});
      expect(request.headers['Authorization'], 'Bearer access-one');
      expect(request.data, isNull);
      expect(f.storage.value?.user?.marketId, isNull);
      expect(f.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  test('optional media/description and unknown access status parse safely', () {
    final json = serviceJson(status: 'FUTURE_STATUS');
    (json['service'] as Map)['description'] = null;
    final service = CustomerService.fromJson(json);
    expect(service.description, isNull);
    expect(service.imageUrl, isNull);
    expect(service.badge, 'Check availability');
    (json['service'] as Map)['coverImage'] = {
      'url': 'https://example.invalid/cover.jpg',
    };
    (json['service'] as Map)['iconUrl'] = 'https://example.invalid/icon.png';
    expect(
      CustomerService.fromJson(json).imageUrl,
      'https://example.invalid/cover.jpg',
    );
    expect(safeImageUrl('file:///private/image.png'), isNull);
  });
  test(
    'all documented access badges remain distinct and restricted is visible',
    () {
      final badges =
          [
                'ELIGIBLE',
                'CHECK_OPTION',
                'NEEDS_DETAILS',
                'PENDING_REVIEW',
                'REJECTED',
                'RESTRICTED',
              ]
              .map(
                (status) =>
                    CustomerService.fromJson(serviceJson(status: status)).badge,
              )
              .toSet();
      expect(badges.length, 6);
      expect(badges, contains('Restricted'));
    },
  );
  test(
    'single active market is selected but requires explicit Continue',
    () async {
      final d = DiscoveryFixture();
      d.f.adapter.marketsBody = [
        marketJson(),
        {...marketJson(id: 2), 'status': 'INACTIVE'},
      ];
      await d.start();
      addTearDown(d.dispose);
      expect(d.discovery.markets.length, 1);
      expect(d.discovery.candidate?.id, 1);
      expect(d.discovery.confirmed, isFalse);
      expect(d.discovery.services, isEmpty);
      await d.discovery.continueMarket();
      await waitForState(
        d.discovery,
        () => d.discovery.serviceStage == DiscoveryStage.ready,
      );
      expect(d.discovery.confirmed, isTrue);
      expect(d.discovery.services.single.id, 3);
    },
  );
  for (final ambiguous in [false, true]) {
    test(
      'multiple markets ${ambiguous ? 'do not guess among same-country markets' : 'suggest unique saved country match'}',
      () async {
        final d = DiscoveryFixture();
        d.f.adapter.marketsBody = [
          marketJson(),
          marketJson(
            id: 2,
            name: ambiguous ? 'Sri Lanka' : 'United States',
            country: ambiguous ? 'LK' : 'US',
          ),
        ];
        await d.start();
        addTearDown(d.dispose);
        expect(d.discovery.candidate?.id, ambiguous ? isNull : 1);
        expect(d.discovery.countrySuggested, !ambiguous);
        d.discovery.select(2);
        expect(d.discovery.candidate?.id, 2);
        d.discovery.select(999);
        expect(d.discovery.candidate?.id, 2);
      },
    );
  }
  test('unknown profile country does not fall back to device locale or first market', () async {
    final d = DiscoveryFixture();
    d.f.adapter.savedProfile['country'] = 'Unknown';
    d.f.adapter.marketsBody = [
      marketJson(),
      marketJson(id: 2, name: 'United States', country: 'US'),
    ];
    await d.start();
    addTearDown(d.dispose);
    expect(d.discovery.candidate, isNull);
    expect(d.discovery.countrySuggested, isFalse);
  });
  test(
    'empty markets and server errors remain distinct; retry recovers',
    () async {
      final d = DiscoveryFixture();
      d.f.adapter.marketsBody = [];
      await d.start();
      addTearDown(d.dispose);
      expect(d.discovery.marketStage, DiscoveryStage.ready);
      expect(d.discovery.candidate, isNull);
      d.f.adapter.marketsStatus = 500;
      await d.discovery.loadMarkets();
      expect(d.discovery.marketStage, DiscoveryStage.failure);
      d.f.adapter.marketsStatus = 200;
      d.f.adapter.marketsBody = [marketJson()];
      await d.discovery.loadMarkets();
      expect(d.discovery.candidate?.id, 1);
    },
  );
  test(
    'market changes ignore late catalog and logout clears selection',
    () async {
      final d = DiscoveryFixture();
      d.f.adapter.marketsBody = [
        marketJson(),
        marketJson(id: 2, name: 'United States', country: 'US'),
      ];
      d.f.adapter.serviceBodies[2] = [
        serviceJson(id: 22, name: 'Second market service'),
      ];
      await d.start();
      addTearDown(d.dispose);
      final pending = Completer<void>();
      d.f.adapter.pendingServices[1] = pending;
      await d.discovery.continueMarket();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      d.discovery.select(2);
      await d.discovery.continueMarket();
      await waitForState(
        d.discovery,
        () => d.discovery.serviceStage == DiscoveryStage.ready,
      );
      expect(d.discovery.services.single.id, 22);
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(d.discovery.services.single.id, 22);
      await d.f.controller.logout();
      expect(d.discovery.activeMarket, isNull);
      expect(d.discovery.services, isEmpty);
    },
  );
  test(
    'pending service result cannot restore selection after logout',
    () async {
      final d = DiscoveryFixture();
      await d.start();
      addTearDown(d.dispose);
      final pending = Completer<void>();
      d.f.adapter.pendingServices[1] = pending;
      await d.discovery.continueMarket();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await d.f.controller.logout();
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(d.discovery.services, isEmpty);
      expect(d.discovery.confirmed, isFalse);
    },
  );
  for (final status in [400, 403, 500]) {
    test('service HTTP $status is an error, not no services', () async {
      final d = DiscoveryFixture();
      d.f.adapter.servicesStatus = status;
      await d.start();
      addTearDown(d.dispose);
      await d.discovery.continueMarket();
      await waitForState(
        d.discovery,
        () => d.discovery.serviceStage != DiscoveryStage.loading,
      );
      expect(d.discovery.serviceStage, DiscoveryStage.failure);
      d.f.adapter.servicesStatus = 200;
      await d.discovery.loadServices();
      expect(d.discovery.services.single.id, 3);
    });
  }
  testWidgets(
    'single-market home opens expanded category; catalog search and market switch work',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.serviceBodies[1] = [
        serviceJson(),
        {
          ...serviceJson(id: 4, name: 'Restricted care', status: 'RESTRICTED'),
          'service': {
            ...(serviceJson(id: 4, name: 'Restricted care')['service']
                as Map<String, Object?>),
            'description': 'Care and support',
          },
        },
      ];
      await marketEntry(tester, f);
      expect(find.text('Where do you need care?'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await continueMarket(tester);
      expect(find.text('Jane'), findsOneWidget);
      expect(find.text('Nursing'), findsOneWidget);
      expect(find.text('Restricted care'), findsOneWidget);
      expect(find.text('Restricted'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-service-4')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-service-4')));
      await tester.pumpAndSettle();
      expect(find.text('Get a Service'), findsOneWidget);
      expect(find.text('Home Care'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-service-search')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-service-search')),
        'nothing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching services'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-service-search')),
        'nursing',
      );
      await tester.pumpAndSettle();
      expect(find.text('Restricted care'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-services-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-home-market')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-home-account')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-account-market')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-account-market')));
      await tester.pumpAndSettle();
      expect(find.text('Where do you need care?'), findsOneWidget);
    },
  );
  testWidgets(
    'multiple markets use dropdown and keep Continue disabled without a match',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.savedProfile['country'] = 'Unknown';
      f.adapter.marketsBody = [
        marketJson(),
        marketJson(id: 2, name: 'United States', country: 'US'),
      ];
      await marketEntry(tester, f);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(
        tester
            .widget<BThereButton>(
              find.byKey(const ValueKey('customer-market-continue')),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').last);
      await tester.pumpAndSettle();
      await continueMarket(tester);
      expect(
        f.adapter.requests
            .lastWhere((r) => r.path.startsWith('/customers/me/services?'))
            .uri
            .queryParameters,
        {'marketId': '2'},
      );
      expect(find.text('United States'), findsNothing);
      expect(find.text('Explore Services'), findsOneWidget);
    },
  );
  testWidgets('market and home are accessible on narrow large-text screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final f = Fixture();
    addTearDown(f.dispose);
    await marketEntry(tester, f);
    await continueMarket(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-service-3')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
