import 'package:provider_app/features/home/presentation/provider_home_widgets.dart';

import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/presentation/provider_placeholder_screen.dart';
import 'package:provider_app/app/presentation/provider_tabs.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/presentation/service_catalog_card.dart';
import 'package:provider_app/features/services/presentation/service_catalog_loading.dart';

import 'email_registration_onboarding_test.dart' show OnboardingFixture;
import 'provider_shell_test.dart' show destination;
import 'service_first_test.dart' show ServiceFixture, pump, path;
import 'support/fake_service_repository.dart';
import 'support/fake_session_storage.dart';

void main() {
  for (final tab in [
    ProviderTab.profile,
    ProviderTab.requests,
    ProviderTab.messages,
  ]) {
    testWidgets(
      '${tab.label} placeholder handles optional description safely',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: BThereTheme.authentication(),
            home: ProviderPlaceholderScreen(tab: tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(tab.label), findsOneWidget);
        final description = tab.description;
        if (description != null) {
          expect(find.text(description), findsOneWidget);
        } else {
          expect(find.text('null'), findsNothing);
          expect(find.text(''), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final tab in ProviderTab.values.where(
    (tab) => tab.description != null,
  )) {
    testWidgets(
      '${tab.label} opens a selected temporary tab with no backend reads',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final f = ServiceFixture();
        await pump(tester, f, route: null);
        final reads = (
          f.services.loads,
          f.services.assignmentLoads,
          f.completion.calls,
        );
        await tester.tap(destination(tab.label));
        await tester.pumpAndSettle();
        expect(path(f), tab.path);
        expect(
          tester
              .widget<HomeNavigation>(find.byType(HomeNavigation))
              .selectedIndex,
          tab.index,
        );
        expect(find.byType(HomeNavigation), findsOneWidget);
        expect(find.byType(HomeNavigation), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ProviderPlaceholderScreen),
            matching: find.text(tab.description!),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            '${tab.label}\nTab ${const [0, 2, 1, 3, 4].indexOf(tab.index) + 1} of 5',
          ),
          findsOneWidget,
        );
        expect((
          f.services.loads,
          f.services.assignmentLoads,
          f.completion.calls,
        ), reads);
        await tester.tap(destination('Services'));
        await tester.pumpAndSettle();
        expect(path(f), AppRoutes.services);
        expect(
          tester
              .widget<HomeNavigation>(find.byType(HomeNavigation))
              .selectedIndex,
          1,
        );
        semantics.dispose();
      },
    );
  }

  for (final authenticated in [false, true]) {
    testWidgets(
      'placeholder deep links preserve ${authenticated ? "incomplete-profile" : "unauthenticated"} gate',
      (tester) async {
        final f = OnboardingFixture();
        addTearDown(f.dispose);
        if (authenticated) {
          f.storage.session = testSession();
          f.adapter.completion['profileCompleted'] = false;
        }
        await f.pump(tester);
        for (final tab in ProviderTab.values.where(
          (tab) => tab.description != null,
        )) {
          f.container.read(appRouterProvider).go(tab.path);
          await tester.pumpAndSettle();
          expect(f.path, authenticated ? AppRoutes.profile : AppRoutes.auth);
          expect(find.byType(HomeNavigation), findsNothing);
        }
      },
    );
  }

  for (final width in [360.0, 430.0]) {
    testWidgets(
      'backend service tiles use four compact columns at width $width and omit descriptions',
      (tester) async {
        tester.view.physicalSize = Size(width, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = ServiceFixture(existing: true);
        await pump(tester, f);
        final first = tester.getRect(
          find.byKey(const ValueKey('main-service-3')),
        );
        final second = tester.getRect(
          find.byKey(const ValueKey('main-service-9')),
        );
        expect(first.top, second.top);
        expect(second.left, greaterThan(first.right));
        expect(first.height, second.height);
        expect(first.left, 16);
        expect(second.left - first.right, 8);
        expect(first.height / first.width, closeTo(202 / 158, .1));
        expect(find.byType(ServiceStatusBadge), findsNothing);
        expect(find.text('Home nursing services'), findsNothing);
        expect(find.text('Home Nurse'), findsOneWidget);
        expect(find.text('Other service'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('service-status-setupRequired')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('service-status-available')),
          findsOneWidget,
        );
        expect(find.byTooltip('Refresh services'), findsOneWidget);
        expect(find.text('Refresh services'), findsNothing);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
      },
    );
  }

  testWidgets(
    'long names have three-line ellipsis and a single full-label semantic button',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final f = ServiceFixture();
      final longName = List.filled(12, 'Long service name').join(' ');
      f.services.catalog = Success(
        parseActiveProviderServices([
          serviceJson(name: longName),
          serviceJson(id: 9),
          serviceJson(id: 20),
        ]),
      );
      await pump(tester, f);
      final title = tester.widget<Text>(find.text(longName));
      expect(title.maxLines, 3);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.bySemanticsLabel('$longName, Available'), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        4,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'pull-to-refresh reuses the three existing reloads and blocks a concurrent header refresh',
    (tester) async {
      final f = ServiceFixture();
      await pump(tester, f);
      final before = (
        f.services.loads,
        f.services.assignmentLoads,
        f.completion.calls,
      );
      f.services.pendingLoad = Completer<Result<List<ProviderServiceType>>>();
      await tester.dragFrom(
        tester.getTopLeft(find.byType(SingleChildScrollView)) +
            const Offset(40, 20),
        const Offset(0, 500),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(f.services.loads, before.$1 + 1);
      expect(find.byType(ServiceCatalogLoading), findsOneWidget);
      expect(find.byType(BThereSkeleton), findsNWidgets(24));
      expect(find.byType(ServiceCatalogCard), findsNothing);
      expect(f.services.assignmentLoads, before.$2 + 1);
      expect(f.completion.calls, before.$3 + 1);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('refresh-services')))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('refresh-services')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(f.services.loads, before.$1 + 1);
      f.services.pendingLoad!.complete(f.services.catalog);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCatalogLoading), findsNothing);
      expect(find.byType(ServiceCatalogCard), findsWidgets);
      expect(f.services.submissions, 0);
    },
  );

  testWidgets('large text uses readable single-column tiles without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final f = ServiceFixture(existing: true);
    await pump(tester, f);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('main-service-9')));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCatalogCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
