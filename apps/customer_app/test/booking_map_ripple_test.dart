import 'dart:async';

import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/app/widgets/search_range_ripple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'booking_fixture.dart';
import 'customer_test_map.dart';

class _MapController extends Fake implements GoogleMapController {
  int moves = 0, projections = 0;
  bool disposed = false;
  Offset origin = const Offset(160, 120);
  double zoomScale = 1;
  Completer<void>? projectionGate, moveGate;

  @override
  Future<void> moveCamera(CameraUpdate update) async {
    moves++;
    await moveGate?.future;
  }

  @override
  Future<ScreenCoordinate> getScreenCoordinate(LatLng point) async {
    projections++;
    await projectionGate?.future;
    return ScreenCoordinate(
      x: (origin.dx + (point.longitude - 79.85) * 1000 * zoomScale).round(),
      y: (origin.dy - (point.latitude - 6.92) * 1000 * zoomScale).round(),
    );
  }

  @override
  void dispose() {
    disposed = true;
  }
}

CustomerMapState _map(WidgetTester tester) =>
    tester.widget<CustomerTestMap>(find.byType(CustomerTestMap)).state;

SearchRangeRipplePainter _ripple(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('search-range-ripple-paint')),
            )
            .painter!
        as SearchRangeRipplePainter;

Future<void> _render(
  WidgetTester tester, {
  String token = 'initial',
  GeoPoint? point = const GeoPoint(6.92, 79.85),
  bool reduced = false,
  double height = 300,
  List<ProviderCandidate> candidates = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduced, devicePixelRatio: 1),
            child: Scaffold(
              body: BookingLocationPicker(
                point: point,
                onChanged: (_) {},
                filterPulseKey: token,
                height: height,
                candidates: candidates,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<_MapController> _attach(WidgetTester tester) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final controller = _MapController();
  _map(tester).onCreated(controller);
  await tester.pump();
  _map(tester).onCameraIdle!();
  await tester.pump();
  await tester.pump();
  return controller;
}

void main() {
  testWidgets(
    'one shot ripple restarts cleanly and never drives map updates per frame',
    (tester) async {
      await _render(tester);
      final controller = await _attach(tester);
      final element = tester.element(find.byType(CustomerTestMap));
      expect(_ripple(tester).animation.value, 0);
      expect(_ripple(tester).center, const Offset(160, 120));
      await _render(tester, token: 'female');
      await tester.pump(const Duration(milliseconds: 500));
      expect(_ripple(tester).animation.value, closeTo(500 / 2800, .01));
      final projections = controller.projections;
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.projections, projections);
      expect(controller.moves, 1);
      expect(
        identical(element, tester.element(find.byType(CustomerTestMap))),
        isTrue,
      );
      expect(_map(tester).circles.single.radius, 10000);
      await _render(tester, token: 'tamil');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_ripple(tester).animation.value, lessThan(.1));
      await tester.pumpAndSettle();
      expect(_ripple(tester).animation.value, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider results and panel size preserve camera; pan reprojects ripple',
    (tester) async {
      await _render(tester);
      final controller = await _attach(tester);
      await _render(
        tester,
        token: 'duration-6h',
        height: 270,
        candidates: [ProviderCandidate.parse(candidateJson())],
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.moves, 1);
      final oldRadius = _ripple(tester).radius!;
      controller.origin = const Offset(220, 90);
      controller.zoomScale = 1.5;
      _map(tester).onCameraMoveStarted!();
      _map(tester).onCameraMove!(_map(tester).camera);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(_ripple(tester).center, const Offset(220, 90));
      expect(_ripple(tester).radius!, greaterThan(oldRadius));
      _map(tester).onCameraIdle!();
      await tester.pumpAndSettle();
      expect(controller.moves, 1);
    },
  );

  testWidgets(
    'manual location works without idle callback and later filters replay',
    (tester) async {
      await _render(tester);
      final controller = await _attach(tester);
      controller.moveGate = Completer<void>();
      await _render(
        tester,
        token: 'new-location',
        point: const GeoPoint(6.93, 79.86),
      );
      expect(_ripple(tester).animation.value, 0);
      expect(_ripple(tester).center, isNull);
      await tester.pump(const Duration(milliseconds: 130));
      expect(controller.moves, 2);
      expect(_ripple(tester).animation.value, 0);
      controller.moveGate!.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_ripple(tester).animation.value, greaterThan(0));
      await tester.pumpAndSettle();
      await _render(
        tester,
        token: 'new-location-tamil',
        point: const GeoPoint(6.93, 79.86),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(_ripple(tester).animation.value, greaterThan(0));
      expect(controller.moves, 2);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('late projection completion after disposal is ignored', (
    tester,
  ) async {
    await _render(tester);
    final controller = await _attach(tester);
    controller.projectionGate = Completer<void>();
    await _render(tester, token: 'new-filter');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.projectionGate!.complete();
    await tester.pumpAndSettle();
    expect(controller.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion stops an active ripple and suppresses later pulses',
    (tester) async {
      await _render(tester);
      await _attach(tester);
      await _render(tester, token: 'date');
      await tester.pump(const Duration(milliseconds: 200));
      final animation = _ripple(tester).animation;
      expect(animation.value, greaterThan(0));
      await _render(tester, token: 'time', reduced: true);
      await tester.pumpAndSettle();
      expect(animation.value, 0);
      expect(_ripple(tester).animation.value, 0);
      await _render(tester, token: 'time');
      expect(_ripple(tester).animation.value, 0);
    },
  );
}
