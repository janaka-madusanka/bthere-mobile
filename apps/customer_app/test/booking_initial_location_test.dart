import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';

import 'customer_test_map.dart';

void main() {
  for (final manual in [false, true]) {
    testWidgets(
      'prepared GPS is reused and respects manual selection: $manual',
      (tester) async {
        final gps = Completer<GeoPoint>();
        GeoPoint? selected;
        var extraGpsReads = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
              customerDeviceLocationProvider.overrideWithValue(() async {
                extraGpsReads++;
                return const GeoPoint(1, 1);
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => BookingLocationPicker(
                    point: selected,
                    initialLocation: gps.future,
                    autoLocate: true,
                    onChanged: (p) => setState(() => selected = p),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (manual) {
          tester
              .widget<CustomerTestMap>(find.byType(CustomerTestMap))
              .state
              .onSelect!(
            tester
                .widget<CustomerTestMap>(find.byType(CustomerTestMap))
                .state
                .camera
                .target,
          );
          await tester.pump();
        }
        final manuallySelected = selected;
        gps.complete(const GeoPoint(6.9, 79.8));
        await tester.pumpAndSettle();
        expect(extraGpsReads, 0);
        expect(selected?.latitude, manual ? manuallySelected!.latitude : 6.9);
        expect(
          selected?.longitude,
          manual ? manuallySelected!.longitude : 79.8,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
