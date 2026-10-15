import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/services/presentation/service_catalog_card.dart';

import 'service_first_test.dart' show ServiceFixture, pump, path;
import 'support/fake_service_repository.dart';

const names = [
  'Caregiving',
  'Home Support',
  'Meal Preparation',
  'Medication Support',
  'Mobility Assistance',
  'Transportation',
  'Companionship',
  'Pet Care',
  'Childcare',
  'Handyman',
  'Garden Care',
  'Shopping & Errands',
];

ServiceFixture fixture({bool registered = false}) {
  final f = ServiceFixture();
  f.services.catalog = Success(
    parseActiveProviderServices([
      for (final (index, name) in names.indexed)
        serviceJson(id: index + 20, name: name)
          ..['description'] = switch (name) {
            'Caregiving' => 'Support with daily living activities',
            'Meal Preparation' => 'Nutritious and personalized meals',
            _ => 'Help with daily household tasks',
          },
      serviceJson(id: 40, name: 'Household Support')
        ..['description'] = 'Help with daily household tasks',
    ]),
  );
  if (registered) {
    f.services.assignments = Success([
      for (final (index, id) in [20, 22, 40].indexed)
        parseProviderServiceAssignment(
          assignmentJson(typeId: id)
            ..['assignmentId'] = index + 100
            ..['providerTypeName'] = id == 40
                ? 'Household Support'
                : names[id - 20],
        ),
    ]);
  }
  return f;
}

void main() {
  testWidgets('documented Caregiver name retains API ID and Figma artwork', (
    tester,
  ) async {
    final f = ServiceFixture();
    f.services.catalog = Success(
      parseActiveProviderServices([serviceJson(id: 55, name: 'Caregiver')]),
    );
    await pump(tester, f);
    expect(find.byKey(const ValueKey('featured-service-55')), findsOneWidget);
    expect(find.text('Caregiver'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('featured-service-55')));
    await tester.pumpAndSettle();
    expect(path(f), AppRoutes.serviceDetail(55));
  });

  testWidgets(
    'carousel pagination reaches the last service and updates selection',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final f = fixture();
      await pump(tester, f);
      final lastPage = find.bySemanticsLabel('Featured services page 3 of 3');
      await tester.tap(lastPage);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(lastPage).properties.selected, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'registration absent from active catalog keeps the backend name and ID',
    (tester) async {
      final f = ServiceFixture();
      f.services.assignments = Success([
        parseProviderServiceAssignment(
          assignmentJson(typeId: 55)
            ..['providerTypeName'] = 'Previously registered service',
        ),
      ]);
      await pump(tester, f);
      expect(find.text('My Registered Services'), findsOneWidget);
      expect(find.text('Previously registered service'), findsOneWidget);
      expect(find.byKey(const ValueKey('featured-service-55')), findsOneWidget);
      expect(find.byKey(const ValueKey('main-service-55')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search and registration filters use API services without new reads',
    (tester) async {
      final f = fixture(registered: true);
      await pump(tester, f);
      expect(find.text('My Registered Services'), findsOneWidget);
      final reads = (f.services.loads, f.services.assignmentLoads);
      await tester.enterText(
        find.byKey(const ValueKey('search-services')),
        'meal',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCatalogCard), findsOneWidget);
      expect(find.byKey(const ValueKey('main-service-22')), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter services'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registered services'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCatalogCard), findsNWidgets(3));
      await tester.enterText(
        find.byKey(const ValueKey('search-services')),
        'no such service',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching services'), findsOneWidget);
      await tester.tap(find.text('Clear search and filters'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCatalogCard), findsNWidgets(13));
      expect((f.services.loads, f.services.assignmentLoads), reads);
      expect(f.services.submissions, 0);
    },
  );

  testWidgets('featured selection uses backend ID and existing detail route', (
    tester,
  ) async {
    final f = fixture();
    await pump(tester, f);
    expect(find.textContaining('Hot Services'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('featured-service-20')));
    await tester.pumpAndSettle();
    expect(path(f), AppRoutes.serviceDetail(20));
    expect(f.services.submissions, 0);
  });

  for (final registered in [false, true]) {
    for (final scale in [1.0, 1.3, 2.5]) {
      testWidgets(
        'explore registered=$registered scale=$scale fits narrow viewport',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pump(tester, fixture(registered: registered));
          await tester.ensureVisible(
            find.byKey(const ValueKey('main-service-31')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('Services Figma reference registered=$registered', (
      tester,
    ) async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final f = fixture(registered: registered);
      await pump(tester, f);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: const RepaintBoundary(
            key: ValueKey('services-preview'),
            child: BThereProviderApp(),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(RepaintBoundary).first);
        for (final file in [
          'new_imgReferencePhotography',
          'registered_imgReferencePhotography',
        ]) {
          await precacheImage(AssetImage('assets/services/$file.png'), context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('services-preview')),
        matchesGoldenFile(
          'goldens/provider_services_${registered ? "registered" : "new"}.png',
        ),
      );
    });
  }
}
