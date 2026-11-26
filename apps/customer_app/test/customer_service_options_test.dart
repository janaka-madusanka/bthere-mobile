import 'dart:async';

import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';
import 'package:customer_app/features/discovery/data/customer_discovery_repository.dart';
import 'package:customer_app/features/discovery/domain/customer_discovery.dart';
import 'package:customer_app/features/discovery/presentation/customer_discovery_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_auth_test.dart'
    show Fixture, marketJson, optionJson, serviceJson;
import 'customer_discovery_test.dart'
    show DiscoveryFixture, marketEntry, continueMarket, waitForState;

void main() {
  testWidgets(
    'services and expanded options use skeletons until their reads finish',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await marketEntry(tester, f);
      await continueMarket(tester);
      await tester.tap(find.byKey(const ValueKey('customer-nav-services')));
      await tester.pumpAndSettle();
      final discovery = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('customer-service-search'))),
      ).read(customerDiscoveryProvider);
      final servicesGate = Completer<void>();
      f.adapter.pendingServices[1] = servicesGate;
      final load = discovery.loadServices();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('services-loading-skeleton')),
        findsOneWidget,
      );
      servicesGate.complete();
      await tester.pumpAndSettle();
      await load;
      expect(
        find.byKey(const ValueKey('services-loading-skeleton')),
        findsNothing,
      );
      final optionsGate = Completer<void>();
      f.adapter.pendingOptions['1/3'] = optionsGate;
      discovery.loadOptions(3, retry: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('service-options-loading-skeleton')),
        findsOneWidget,
      );
      optionsGate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('service-options-loading-skeleton')),
        findsNothing,
      );
      expect(find.text('Home Care'), findsOneWidget);
    },
  );
  testWidgets(
    'service list keeps names and restrictions while descriptions stay in details',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.serviceBodies[1] = [serviceJson(status: 'CHECK_OPTION')];
      f.adapter.optionBodies['1/3'] = [optionJson(access: 'PENDING_REVIEW')];
      await marketEntry(tester, f);
      await continueMarket(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-service-3')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-service-3')));
      await tester.pumpAndSettle();
      expect(find.text('Home nursing services'), findsNothing);
      expect(find.text('Care at your location'), findsNothing);
      expect(find.text('Check options'), findsNothing);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Home Care'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-option-12')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-option-12')));
      await tester.pumpAndSettle();
      expect(find.text('Care at your location'), findsOneWidget);
    },
  );
  for (final hasIcon in [true, false]) {
    testWidgets(
      'option row uses ${hasIcon ? 'its icon' : 'a fallback'} instead of the cover image',
      (tester) async {
        final f = Fixture();
        addTearDown(f.dispose);
        final row = optionJson();
        final option = row['option'] as Map;
        option['icon'] = hasIcon
            ? {'url': 'https://example.invalid/option-icon.png'}
            : null;
        option['iconUrl'] = null;
        option['coverImage'] = {
          'url': 'https://example.invalid/option-cover.png',
        };
        f.adapter.optionBodies['1/3'] = [row];
        await marketEntry(tester, f);
        await continueMarket(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-service-3')),
        );
        await tester.tap(find.byKey(const ValueKey('customer-service-3')));
        await tester.pumpAndSettle();
        final icon = tester.widget<CatalogIcon>(
          find.descendant(
            of: find.byKey(const ValueKey('customer-option-12')),
            matching: find.byType(CatalogIcon),
          ),
        );
        expect(
          icon.url,
          hasIcon ? 'https://example.invalid/option-icon.png' : null,
        );
        expect(
          CustomerServiceOption.fromJson(row).imageUrl,
          'https://example.invalid/option-cover.png',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });

  for (final entry in ['View all', 'Services']) {
    testWidgets(
      '$entry opens every backend category without eagerly loading options',
      (tester) async {
        final f = Fixture();
        addTearDown(f.dispose);
        f.adapter.serviceBodies[1] = [
          for (var i = 1; i <= 9; i++) serviceJson(id: i, name: 'Category $i'),
        ];
        await marketEntry(tester, f);
        await continueMarket(tester);
        expect(find.byKey(const ValueKey('customer-service-9')), findsNothing);
        await tester.ensureVisible(find.text(entry).first);
        await tester.tap(find.text(entry).first);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('customer-category-9')),
          findsOneWidget,
        );
        expect(
          f.adapter.requests.where(
            (request) => request.path.endsWith('/options'),
          ),
          isEmpty,
        );
      },
    );
  }

  test('options request uses service.id, selected market and authenticated GET with no body', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    final options = await CustomerDiscoveryRepository(f.service).options(2, 7);
    final request = f.adapter.requests.last;
    expect(request.uri.path, '/api/v1/customers/me/services/7/options');
    expect(request.method, 'GET');
    expect(request.uri.queryParameters, {'marketId': '2'});
    expect(request.data, isNull);
    expect(request.headers['Authorization'], 'Bearer access-one');
    expect(options.single.serviceId, 7);
  });

  test('options retain independent eligibility, optional media and server ordering', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    f.adapter.optionBodies['1/3'] = [
      optionJson(
        id: 13,
        name: 'Restricted option',
        order: 3,
        access: 'RESTRICTED',
      ),
      optionJson(order: 1),
      {
        ...optionJson(id: 14),
        'option': {
          ...optionJson(id: 14)['option'] as Map,
          'status': 'INACTIVE',
        },
      },
    ];
    final rows = await CustomerDiscoveryRepository(f.service).options(1, 3);
    expect(rows.map((o) => o.id), [12, 13]);
    expect(rows.first.imageUrl, isNull);
    expect(rows.last.access.badge, 'Restricted');
    expect(rows.first.access.badge, 'Available');
  });

  test(
    'wrong parent, duplicate IDs and wrapped responses are contract errors',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      final repo = CustomerDiscoveryRepository(f.service);
      for (final body in [
        [optionJson(serviceId: 9)],
        [optionJson(), optionJson()],
        {
          'data': [optionJson()],
        },
      ]) {
        f.adapter.optionBodies['1/3'] = body;
        await expectLater(
          repo.options(1, 3),
          throwsA(isA<DiscoveryContractException>()),
        );
      }
    },
  );

  test('options cache avoids duplicate requests and retry recovers without changing the catalog', () async {
    final d = DiscoveryFixture();
    await d.start();
    addTearDown(d.dispose);
    await d.discovery.continueMarket();
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    d.f.adapter.optionsStatus = 500;
    await d.discovery.loadOptions(3);
    expect(d.discovery.optionsFor(3).stage, DiscoveryStage.failure);
    expect(d.discovery.serviceStage, DiscoveryStage.ready);
    d.f.adapter.optionsStatus = 200;
    await d.discovery.loadOptions(3, retry: true);
    await d.discovery.loadOptions(3);
    expect(d.discovery.optionsFor(3).options.single.id, 12);
    expect(
      d.f.adapter.requests.where((r) => r.path.contains('/3/options')).length,
      2,
    );
    await d.discovery.loadOptions(999);
    expect(d.discovery.optionsFor(999).stage, DiscoveryStage.idle);
  });

  test('market switch discards late sub-services even when both markets share service IDs', () async {
    final d = DiscoveryFixture();
    d.f.adapter.marketsBody = [
      marketJson(),
      marketJson(id: 2, name: 'Second market', country: 'US'),
    ];
    d.f.adapter.optionBodies['2/3'] = [
      optionJson(id: 22, name: 'Second market option'),
    ];
    await d.start();
    addTearDown(d.dispose);
    await d.discovery.continueMarket();
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    final pending = Completer<void>();
    d.f.adapter.pendingOptions['1/3'] = pending;
    final stale = d.discovery.loadOptions(3);
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    d.discovery.select(2);
    await d.discovery.continueMarket();
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    await d.discovery.loadOptions(3);
    pending.complete();
    await stale;
    expect(d.discovery.optionsFor(3).options.single.id, 22);
  });

  test('logout clears option cache and discards a pending response', () async {
    final d = DiscoveryFixture();
    await d.start();
    addTearDown(d.dispose);
    await d.discovery.continueMarket();
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    final pending = Completer<void>();
    d.f.adapter.pendingOptions['1/3'] = pending;
    final stale = d.discovery.loadOptions(3);
    await d.f.controller.logout();
    pending.complete();
    await stale;
    expect(d.discovery.optionsFor(3).stage, DiscoveryStage.idle);
    expect(d.discovery.optionsFor(3).options, isEmpty);
  });

  testWidgets(
    'service groups show options immediately, cache reads and See all expands the grid',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.serviceBodies[1] = [
        serviceJson(),
        serviceJson(id: 4, name: 'Pet Care'),
      ];
      f.adapter.optionBodies['1/3'] = [
        for (var i = 0; i < 5; i++)
          optionJson(id: 12 + i, name: 'Care option $i', order: i),
      ];
      f.adapter.optionBodies['1/4'] = [
        optionJson(id: 24, serviceId: 4, name: 'Pet sitting'),
      ];
      await marketEntry(tester, f);
      await continueMarket(tester);
      await tester.tap(find.byKey(const ValueKey('customer-nav-services')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-option-12')), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-option-16')), findsNothing);
      expect(find.byKey(const ValueKey('customer-option-24')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('service-see-all-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-option-16')), findsOneWidget);
      expect(
        f.adapter.requests.where((r) => r.path.contains('/3/options')).length,
        1,
      );
      expect(
        f.adapter.requests.where((r) => r.path.contains('/4/options')).length,
        1,
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-service-search')),
        'Pet sitting',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-option-24')), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-option-12')), findsNothing);
    },
  );

  testWidgets('sub-service failures have retry and empty is a distinct state', (
    tester,
  ) async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.optionsStatus = 500;
    await marketEntry(tester, f);
    await continueMarket(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-service-3')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-service-3')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load sub-services'), findsOneWidget);
    f.adapter.optionsStatus = 200;
    f.adapter.optionBodies['1/3'] = [];
    await tester.ensureVisible(find.text('Retry sub-services'));
    await tester.tap(find.text('Retry sub-services'));
    await tester.pumpAndSettle();
    expect(
      find.text('No sub-services available for this market yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'expanded categories remain usable at narrow width with large text',
    (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('customer-service-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-option-12')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
