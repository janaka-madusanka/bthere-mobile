import 'dart:async';

import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';
import 'package:customer_app/features/discovery/data/customer_discovery_repository.dart';
import 'package:customer_app/features/discovery/data/customer_market_selection_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/discovery/presentation/customer_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture, MemoryMarketValues, marketJson;
import 'customer_discovery_test.dart'
    show DiscoveryFixture, marketEntry, continueMarket, waitForState;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Public Sans',
    )..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'))).load();
  });

  test('selection survives a new store and is isolated by account and API environment', () async {
    final driver = MemoryMarketValues();
    final original = CustomerMarketSelectionStore(
      driver,
      apiScope: 'https://one.invalid/api/v1',
    );
    await original.save(12, 2);
    final restarted = CustomerMarketSelectionStore(
      driver,
      apiScope: original.apiScope,
    );
    expect(await restarted.read(12), 2);
    expect(await restarted.read(13), isNull);
    expect(
      await CustomerMarketSelectionStore(
        driver,
        apiScope: 'https://two.invalid/api/v1',
      ).read(12),
      isNull,
    );
    expect(driver.values.values.single, '2');
  });

  test('invalid persisted values cannot become market IDs', () async {
    final driver = MemoryMarketValues();
    final store = CustomerMarketSelectionStore(driver, apiScope: 'test');
    await store.save(12, 1);
    final key = driver.values.keys.single;
    for (final value in ['-1', '0', 'bad', '1.5']) {
      driver.values[key] = value;
      expect(await store.read(12), isNull);
    }
  });

  test('saved market overrides country suggestion and reload restores services for its ID', () async {
    final d = DiscoveryFixture();
    d.f.adapter.marketsBody = [
      marketJson(),
      marketJson(id: 2, name: 'United States', country: 'US'),
    ];
    await d.f.marketStore.save(12, 2);
    await d.start();
    addTearDown(d.dispose);
    expect(d.discovery.activeMarket?.id, 2);
    expect(d.discovery.countrySuggested, isFalse);
    await waitForState(
      d.discovery,
      () => d.discovery.serviceStage == DiscoveryStage.ready,
    );
    expect(d.f.adapter.requests.last.uri.queryParameters, {'marketId': '2'});
    d.discovery.dispose();
    d.discovery = CustomerDiscoveryController(
      CustomerDiscoveryRepository(d.f.service),
      d.f.controller,
      d.profile,
      selectionStore: d.f.marketStore,
    );
    await waitForState(
      d.discovery,
      () => d.discovery.marketStage == DiscoveryStage.ready,
    );
    expect(d.discovery.activeMarket?.id, 2);
  });

  test('removed or inactive saved market requires confirmation of a current active market', () async {
    final d = DiscoveryFixture();
    await d.f.marketStore.save(12, 2);
    d.f.adapter.marketsBody = [
      marketJson(),
      {...marketJson(id: 2), 'status': 'INACTIVE'},
    ];
    await d.start();
    addTearDown(d.dispose);
    expect(d.discovery.confirmed, isFalse);
    expect(d.discovery.candidate?.id, 1);
    expect(d.discovery.serviceStage, DiscoveryStage.idle);
    expect(await d.discovery.continueMarket(), isTrue);
    expect(await d.f.marketStore.read(12), 1);
  });

  test('failed preference read stays retryable without forgetting the previous choice', () async {
    final d = DiscoveryFixture();
    await d.f.marketStore.save(12, 1);
    d.f.marketValues.failRead = true;
    await d.start();
    addTearDown(d.dispose);
    expect(d.discovery.marketStage, DiscoveryStage.failure);
    expect(d.discovery.confirmed, isFalse);
    d.f.marketValues.failRead = false;
    await d.discovery.loadMarkets();
    expect(d.discovery.activeMarket?.id, 1);
  });

  test('failed save does not confirm a market; retry persists it', () async {
    final d = DiscoveryFixture();
    await d.start();
    addTearDown(d.dispose);
    d.f.marketValues.failWrite = true;
    expect(await d.discovery.continueMarket(), isFalse);
    expect(d.discovery.confirmed, isFalse);
    expect(d.discovery.savingMarket, isFalse);
    expect(
      d.discovery.marketError,
      'Unable to save your market. Please try again.',
    );
    d.f.marketValues.failWrite = false;
    expect(await d.discovery.continueMarket(), isTrue);
    expect(await d.f.marketStore.read(12), 1);
  });

  test(
    'late confirmation after logout cannot restore active market or catalog',
    () async {
      final d = DiscoveryFixture();
      await d.start();
      addTearDown(d.dispose);
      final pending = Completer<void>();
      d.f.marketValues.pendingWrite = pending;
      final saving = d.discovery.continueMarket();
      await d.f.controller.logout();
      pending.complete();
      expect(await saving, isFalse);
      expect(d.discovery.confirmed, isFalse);
      expect(d.discovery.services, isEmpty);
    },
  );

  testWidgets(
    'app restart skips selection and Account can change and remember the market',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.marketsBody = [
        marketJson(),
        marketJson(id: 2, name: 'United States', country: 'US'),
      ];
      await marketEntry(tester, f);
      expect(find.text('Where do you need care?'), findsOneWidget);
      await continueMarket(tester);
      expect(await f.marketStore.read(12), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.pump(tester);
      expect(find.text('Where do you need care?'), findsNothing);
      expect(find.text('Explore Services'), findsOneWidget);
      expect(find.text('Service area'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('customer-home-account')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-account-market')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-account-market')));
      await tester.pumpAndSettle();
      expect(find.text('Where do you need care?'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').last);
      await tester.pumpAndSettle();
      await continueMarket(tester);
      expect(await f.marketStore.read(12), 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.pump(tester);
      expect(find.text('Where do you need care?'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerHomeScreen)),
      );
      expect(container.read(customerDiscoveryProvider).activeMarket?.id, 2);
    },
  );
}
