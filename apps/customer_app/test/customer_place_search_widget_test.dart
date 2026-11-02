import 'customer_test_map.dart';

import 'dart:async';

import 'package:customer_app/features/booking/data/customer_place_search.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_dialog.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlaceSearch extends PlaceSearch {
  final queries = <String>[];
  Future<List<PlaceResult>> Function(String)? handler;
  Future<PlaceResult> Function(PlaceResult)? resolver;
  @override
  Future<PlaceResult> resolve(PlaceResult result) =>
      resolver?.call(result) ?? super.resolve(result);
  @override
  Future<List<PlaceResult>> search(String query, {String? countryCode}) {
    queries.add(query);
    return handler?.call(query) ??
        Future.value([
          const PlaceResult(
            'Kurunegala',
            'Kurunegala, Sri Lanka',
            GeoPoint(7.4870464, 80.364908),
          ),
        ]);
  }
}

Future<void> pumpSearch(
  WidgetTester tester,
  FakePlaceSearch service, {
  void Function((GeoPoint, String)?)? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerPlaceSearchProvider.overrideWithValue(service),
        customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<(GeoPoint, String)>(
                      MaterialPageRoute(
                        builder: (_) => const BookingLocationDialog(
                          point: GeoPoint(7.65, 80.2),
                          address: 'Padeniya',
                          radius: 5,
                          title: 'Service location',
                          countryCode: 'LK',
                        ),
                      ),
                    );
                onSelected?.call(result);
              },
              child: const Text('Open search'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open search'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'committing composed text triggers autocomplete without another keystroke',
    (tester) async {
      final service = FakePlaceSearch();
      await pumpSearch(tester, service);
      await tester.tap(find.byKey(const ValueKey('booking-place-query')));
      const text = 'කුරු';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: 0, end: text.length),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.queries, isEmpty);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(service.queries, [text]);
    },
  );
  testWidgets(
    'typing autocompletes after a short debounce without dismissing keyboard',
    (tester) async {
      final service = FakePlaceSearch();
      await pumpSearch(tester, service);
      final query = find.byKey(const ValueKey('booking-place-query'));
      await tester.enterText(query, 'K');
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.queries, isEmpty);
      await tester.enterText(query, 'Kuru');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(query, 'Kurunegala');
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(service.queries, ['Kurunegala']);
      expect(find.widgetWithText(ListTile, 'Kurunegala'), findsOneWidget);
      final editable = tester.widget<EditableText>(
        find.descendant(of: query, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets('clearing or leaving search cancels pending autocomplete', (
    tester,
  ) async {
    final service = FakePlaceSearch();
    await pumpSearch(tester, service);
    final query = find.byKey(const ValueKey('booking-place-query'));
    await tester.enterText(query, 'Kurunegala');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(query, '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.queries, isEmpty);
    await tester.enterText(query, 'Colombo');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.queries, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'only selection resolves a Google prediction and late details cannot override a new query',
    (tester) async {
      final service = FakePlaceSearch();
      final pending = Completer<PlaceResult>();
      var detailCalls = 0;
      service.handler = (_) async => const [
        PlaceResult(
          'Kurunegala',
          'Kurunegala, Sri Lanka',
          null,
          placeId: 'google-place-id',
        ),
      ];
      service.resolver = (_) {
        detailCalls++;
        return pending.future;
      };
      await pumpSearch(tester, service);
      await tester.enterText(
        find.byKey(const ValueKey('booking-place-query')),
        'Kurunegala',
      );
      await tester.tap(find.byKey(const ValueKey('booking-place-search')));
      await tester.pumpAndSettle();
      expect(detailCalls, 0);
      expect(find.bySemanticsLabel('Powered by Google'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Kurunegala'));
      await tester.pump();
      expect(detailCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use this location'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-place-query')),
        'Another place',
      );
      await tester.pump();
      pending.complete(
        const PlaceResult('Old result', 'Old address', GeoPoint(1, 1)),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<CustomerTestMap>(find.byType(CustomerTestMap));
      expect(map.state.camera.target.latitude, 7.65);
      expect(find.text('Old address'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'searching Kurunegala moves the service pin and camera independently of current location',
    (tester) async {
      final service = FakePlaceSearch();
      (GeoPoint, String)? selected;
      await pumpSearch(
        tester,
        service,
        onSelected: (value) => selected = value,
      );
      await tester.enterText(
        find.byKey(const ValueKey('booking-place-query')),
        'Kurunegala',
      );
      expect(service.queries, isEmpty);
      await tester.tap(find.byKey(const ValueKey('booking-place-search')));
      await tester.pumpAndSettle();
      expect(find.text('Kurunegala'), findsWidgets);
      await tester.tap(find.widgetWithText(ListTile, 'Kurunegala'));
      await tester.pumpAndSettle();
      final map = tester.widget<CustomerTestMap>(find.byType(CustomerTestMap));
      expect(map.state.camera.target.latitude, closeTo(7.4870464, .0001));
      expect(map.state.camera.target.longitude, closeTo(80.364908, .0001));
      expect(find.text('Address or landmark'), findsNothing);
      expect(
        find.textContaining('Search where you need the service'),
        findsNothing,
      );
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();
      expect(selected?.$2, 'Kurunegala, Sri Lanka');
      expect(selected?.$1.latitude, 7.4870464);
      expect(find.text('Latitude'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old results are ignored after query changes and empty/error states keep the map usable',
    (tester) async {
      final service = FakePlaceSearch();
      final old = Completer<List<PlaceResult>>();
      service.handler = (query) =>
          query == 'Old place' ? old.future : Future.value([]);
      await pumpSearch(tester, service);
      await tester.enterText(
        find.byKey(const ValueKey('booking-place-query')),
        'Old place',
      );
      await tester.tap(find.byKey(const ValueKey('booking-place-search')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('booking-place-query')),
        'Unknown place',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('booking-place-search')));
      await tester.pumpAndSettle();
      old.complete([
        const PlaceResult('Stale result', 'Old city', GeoPoint(1, 1)),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Stale result'), findsNothing);
      expect(find.textContaining('No locations found'), findsOneWidget);
      service.handler = (_) async =>
          throw const BookingProblem('Search temporarily unavailable.');
      await tester.tap(find.byKey(const ValueKey('booking-place-search')));
      await tester.pumpAndSettle();
      expect(find.text('Search temporarily unavailable.'), findsOneWidget);
      expect(find.byType(CustomerTestMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
