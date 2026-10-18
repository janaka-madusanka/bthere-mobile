import 'package:provider_app/app/presentation/provider_navigation_bar.dart';

import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/presentation/service_catalog_card.dart';
import 'package:provider_app/features/services/domain/provider_service_status.dart';
import 'package:provider_app/features/services/presentation/service_catalog_screen.dart';
import 'package:provider_app/features/services/presentation/service_detail_screen.dart';
import 'package:provider_app/features/home/presentation/provider_home_screen.dart';
import 'package:provider_app/features/home/presentation/provider_home_widgets.dart';

import 'service_first_test.dart' show ServiceFixture, pump, path;
import 'support/fake_service_repository.dart';

Finder destination(String label) => find.descendant(
  of: find.byType(ProviderNavigationBar),
  matching: find.text(label),
);

void main() {
  testWidgets(
    'registered Home service opens Services and Home returns dashboard',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: AppRoutes.home);
      final card = find.byType(HomeRegisteredService).first;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<ProviderNavigationBar>(find.byType(ProviderNavigationBar))
            .selectedIndex,
        1,
      );
      await tester.tap(destination('Home'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.home);
      expect(find.byType(ProviderHomeScreen), findsOneWidget);
      expect(find.byType(ServiceDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'Home service detail returns to the dashboard when Home is tapped',
    (tester) async {
      final f = ServiceFixture();
      f.services.catalog = Success(
        parseActiveProviderServices([
          serviceJson(id: 3, name: 'Home Services'),
        ]),
      );
      await pump(tester, f, route: AppRoutes.home);
      final tile = find.descendant(
        of: find.byType(HomeCategories),
        matching: find.text('Home Services'),
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      await tester.tap(destination('Home'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.home);
      expect(find.byType(ProviderHomeScreen), findsOneWidget);
      expect(find.byType(ServiceDetailScreen), findsNothing);
      expect(find.byType(ProviderNavigationBar), findsOneWidget);
    },
  );

  testWidgets('tab deep links select the matching navigation destination', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    await pump(tester, f, route: null);
    final router = f.container.read(appRouterProvider);
    for (final (route, index) in [
      (AppRoutes.home, 0),
      (AppRoutes.requests, 2),
      (AppRoutes.services, 1),
      (AppRoutes.messages, 3),
      (AppRoutes.account, 4),
      (AppRoutes.serviceDetail(3), 1),
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(path(f), route);
      expect(
        tester
            .widget<ProviderNavigationBar>(find.byType(ProviderNavigationBar))
            .selectedIndex,
        index,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'tab taps open main pages and Services clears its detail history',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      final router = f.container.read(appRouterProvider);
      router.push(AppRoutes.serviceDetail(3));
      await tester.pumpAndSettle();
      await tester.tap(destination('Profile'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.account);
      await tester.tap(destination('Services'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.services);
      expect(find.byType(ServiceDetailScreen), findsNothing);
      router.push(AppRoutes.serviceDetail(3));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      await tester.tap(destination('Services'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.services);
      expect(find.byType(ServiceDetailScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.home);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all five tabs retain the same bar and highlight their destination',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: null);
      final initialSize = tester.getSize(find.byType(ProviderNavigationBar));
      for (final item in [
        (2, AppRoutes.requests),
        (1, AppRoutes.services),
        (3, AppRoutes.messages),
        (4, AppRoutes.account),
        (0, AppRoutes.home),
      ]) {
        await tester.tap(find.byKey(ValueKey('provider-tab-${item.$1}')));
        await tester.pumpAndSettle();
        expect(path(f), item.$2);
        expect(find.byType(ProviderNavigationBar), findsOneWidget);
        expect(
          tester
              .widget<ProviderNavigationBar>(find.byType(ProviderNavigationBar))
              .selectedIndex,
          item.$1,
        );
        expect(tester.getSize(find.byType(ProviderNavigationBar)), initialSize);
        for (final index in [0, 1, 2, 3, 4]) {
          final destination = tester.widget<Semantics>(
            find.byKey(ValueKey('provider-tab-$index')),
          );
          expect(destination.properties.selected, index == item.$1);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'each tab opens its main page after service navigation and back',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      final router = f.container.read(appRouterProvider);
      for (final (label, route) in [
        ('Home', AppRoutes.home),
        ('Opportunities', AppRoutes.requests),
        ('Messages', AppRoutes.messages),
        ('Profile', AppRoutes.account),
        ('Services', AppRoutes.services),
      ]) {
        router.go(AppRoutes.services);
        await tester.pumpAndSettle();
        router.push(AppRoutes.serviceDetail(3));
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        router.push(AppRoutes.serviceDetail(3));
        await tester.pumpAndSettle();
        await tester.tap(destination(label));
        await tester.pumpAndSettle();
        expect(path(f), route);
        expect(find.byType(ServiceDetailScreen), findsNothing);
        await tester.tap(destination('Services'));
        await tester.pumpAndSettle();
        expect(path(f), AppRoutes.services);
        expect(find.byType(ServiceDetailScreen), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'completed entry starts Home; branches retain Services state without extra reads',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: null);
      expect(path(f), AppRoutes.home);
      expect(find.text('Your Registered Services'), findsOneWidget);
      expect(find.byType(ProviderNavigationBar), findsOneWidget);
      expect(f.services.loads, 1);
      await tester.tap(destination('Services'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.services);
      expect(
        tester
            .widget<ProviderNavigationBar>(find.byType(ProviderNavigationBar))
            .selectedIndex,
        1,
      );
      final state = tester.state(find.byType(ServiceCatalogScreen));
      final loads = f.services.loads;
      expect(find.text('Home Nurse'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(ServiceCatalogCard),
          matching: find.text('Home nursing services'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('service-status-setupRequired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('service-status-available')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('service-status-setupRequired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('service-status-available')),
        findsOneWidget,
      );
      await tester.tap(destination('Home'));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.home);
      await tester.tap(destination('Services'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.state(find.byType(ServiceCatalogScreen)), state),
        isTrue,
      );
      expect(f.services.loads, loads);
      expect(find.byType(ProviderNavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'nested detail retains one navigation and back restores the Services shell',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      await tester.ensureVisible(find.byKey(const ValueKey('main-service-3')));
      await tester.tap(find.byKey(const ValueKey('main-service-3')));
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.serviceDetail(3));
      expect(find.byType(ProviderNavigationBar), findsOneWidget);
      final router = f.container.read(appRouterProvider);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.services);
      expect(find.byType(ProviderNavigationBar), findsOneWidget);
      expect(router.canPop(), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(path(f), AppRoutes.home);
    },
  );

  testWidgets(
    'refresh uses existing three reads once and holds button geometry during busy state',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      final loads = f.services.loads;
      final assignments = f.services.assignmentLoads;
      final completion = f.completion.calls;
      final button = find.byKey(const ValueKey('refresh-services'));
      await tester.ensureVisible(button);
      final size = tester.getSize(button);
      f.services.pendingLoad = Completer<Result<List<ProviderServiceType>>>();
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(f.services.loads, loads + 1);
      expect(f.services.assignmentLoads, assignments + 1);
      expect(f.completion.calls, completion + 1);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      expect(tester.getSize(button), size);
      expect(find.byType(BThereLoadingIndicator), findsWidgets);
      f.services.pendingLoad!.complete(f.services.catalog);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      expect(f.services.submissions, 0);
    },
  );

  testWidgets(
    'error retries current repository then shows empty state and refresh',
    (tester) async {
      final f = ServiceFixture();
      f.services.catalog = const Failure(
        AppFailure(message: 'Synthetic failure'),
      );
      await pump(tester, f);
      expect(find.text('Unable to load services'), findsOneWidget);
      expect(find.text('Synthetic failure'), findsNothing);
      f.services.catalog = const Success([]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No services are available right now.'), findsOneWidget);
      expect(find.byTooltip('Refresh services'), findsOneWidget);
      expect(f.services.loads, 2);
    },
  );

  for (final height in [568.0, 915.0]) {
    testWidgets(
      'many backend services scroll, retain offset, and respect safe area at height $height',
      (tester) async {
        tester.view.physicalSize = Size(320, height);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24, top: 24);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final f = ServiceFixture();
        f.services.catalog = Success(
          parseActiveProviderServices([
            for (var id = 20; id < 45; id++)
              serviceJson(id: id, name: 'Backend service $id'),
          ]),
        );
        await pump(tester, f);
        final lastTile = find.byKey(const ValueKey('main-service-44'));
        await tester.ensureVisible(lastTile);
        await tester.pumpAndSettle();
        expect(find.text('Backend service 44'), findsOneWidget);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offset = scroll.position.pixels;
        expect(offset, greaterThan(0));
        final bar = tester.getRect(find.byType(ProviderNavigationBar));
        expect(bar.bottom, height);
        expect(
          tester.getRect(destination('Services')).bottom,
          lessThanOrEqualTo(height - 24),
        );
        await tester.tap(destination('Messages'));
        await tester.pumpAndSettle();
        await tester.tap(destination('Services'));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, offset);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in [null, ...ProviderServiceStatus.values]) {
    testWidgets(
      'status badge renders ${status?.label ?? "unknown"} on narrow scaled layout',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ServiceStatusBadge(status: status),
              ),
            ),
          ),
        );
        expect(
          find.text(status?.label ?? 'Status unavailable'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
