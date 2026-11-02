import 'customer_test_map.dart';

import 'dart:async';

import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/features/booking/data/customer_location_address.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpMap(
  WidgetTester tester,
  Future<GeoPoint> Function() locate, {
  GeoPoint? initial,
  required void Function(GeoPoint) onChanged,
  bool settle = true,
  Future<String?> Function(GeoPoint)? reverse,
  ValueChanged<String>? onAddressChanged,
}) async {
  GeoPoint? point = initial;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
        customerDeviceLocationProvider.overrideWithValue(locate),
        if (reverse != null)
          customerLocationAddressProvider.overrideWithValue(reverse),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: BookingLocationPicker(
                point: point,
                autoLocate: true,
                onAddressChanged: onAddressChanged,
                onChanged: (value) {
                  setState(() => point = value);
                  onChanged(value);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('startup GPS also fills the address without a manual search', (
    tester,
  ) async {
    String? address;
    GeoPoint? selected;
    await pumpMap(
      tester,
      () async => const GeoPoint(7.48, 80.36),
      onChanged: (point) => selected = point,
      reverse: (point) async {
        expect(point.latitude, 7.48);
        return 'Kurunegala, Sri Lanka';
      },
      onAddressChanged: (value) => address = value,
    );
    expect(selected?.latitude, 7.48);
    expect(address, 'Kurunegala, Sri Lanka');
  });

  testWidgets(
    'a late GPS address cannot replace a subsequent manual pin address',
    (tester) async {
      final pending = Completer<String?>();
      var calls = 0;
      String? address;
      await pumpMap(
        tester,
        () async => const GeoPoint(7.48, 80.36),
        onChanged: (_) {},
        reverse: (_) => ++calls == 1
            ? pending.future
            : Future.value('Manual location address'),
        onAddressChanged: (value) => address = value,
      );
      await tester.tapAt(tester.getCenter(find.byType(CustomerTestMap)));
      await tester.pumpAndSettle();
      pending.complete('Old GPS address');
      await tester.pumpAndSettle();
      expect(address, 'Manual location address');
    },
  );

  testWidgets(
    'new map selects and centers the current device location on startup',
    (tester) async {
      GeoPoint? selected;
      var calls = 0;
      await pumpMap(tester, () async {
        calls++;
        return const GeoPoint(7.48, 80.36);
      }, onChanged: (point) => selected = point);
      expect(calls, 1);
      expect(selected?.latitude, 7.48);
      final camera = tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state
          .camera;
      expect(camera.target.latitude, closeTo(7.48, .0001));
      expect(camera.target.longitude, closeTo(80.36, .0001));
    },
  );
  testWidgets('an existing service pin is preserved and does not trigger GPS', (
    tester,
  ) async {
    var calls = 0;
    await pumpMap(
      tester,
      () async {
        calls++;
        return const GeoPoint(0, 0);
      },
      initial: const GeoPoint(6.92, 79.86),
      onChanged: (_) => fail('Existing pin overwritten'),
    );
    expect(calls, 0);
    expect(
      tester
          .widget<CustomerTestMap>(find.byType(CustomerTestMap))
          .state
          .camera
          .target
          .latitude,
      closeTo(6.92, .0001),
    );
  });
  testWidgets(
    'a late startup GPS result cannot overwrite a manually selected service pin',
    (tester) async {
      final pending = Completer<GeoPoint>();
      GeoPoint? selected;
      await pumpMap(
        tester,
        () => pending.future,
        onChanged: (point) => selected = point,
        settle: false,
      );
      await tester.tapAt(tester.getCenter(find.byType(CustomerTestMap)));
      await tester.pump(const Duration(milliseconds: 350));
      final manual = selected;
      expect(manual, isNotNull);
      pending.complete(const GeoPoint(7.48, 80.36));
      await tester.pumpAndSettle();
      expect(identical(selected, manual), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('denied startup GPS keeps map pin selection available', (
    tester,
  ) async {
    GeoPoint? selected;
    await pumpMap(
      tester,
      () async =>
          throw const BookingProblem('Location permission unavailable.'),
      onChanged: (point) => selected = point,
    );
    expect(find.text('Location permission unavailable.'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(CustomerTestMap)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(selected?.valid, isTrue);
    expect(tester.takeException(), isNull);
  });
}
