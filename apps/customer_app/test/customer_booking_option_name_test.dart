import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/booking/application/customer_booking_option_name.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture, optionJson;

void main() {
  test(
    'option title uses its snapshot and never substitutes a category name',
    () {
      expect(
        bookingOptionName({
          'optionName': ' Hospital Care ',
          'serviceName': 'Caregiver',
        }),
        'Hospital Care',
      );
      expect(
        bookingOptionName({
          'option': {'name': 'Home Care'},
        }),
        'Home Care',
      );
      expect(bookingOptionName({'serviceName': 'Caregiver'}), isNull);
    },
  );
  test('history resolves the exact option ID and does not load another account scope', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.controller.login('test', 'password');
    f.adapter.extraHandler = (r) async {
      if (r.path.contains('/options')) {
        return ResponseBody.fromString(
          jsonEncode([
            optionJson(id: 11, serviceId: 3, name: 'Hospital Care'),
            optionJson(id: 12, serviceId: 3, name: 'Home Care'),
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return null;
    };
    final container = ProviderContainer(
      overrides: [
        customerAuthServiceProvider.overrideWithValue(f.service),
        customerAuthControllerProvider.overrideWithValue(f.controller),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(
        customerBookingOptionNameProvider((
          owner: 12,
          market: 1,
          service: 3,
          option: 12,
        )).future,
      ),
      'Home Care',
    );
    expect(
      await container.read(
        customerBookingOptionNameProvider((
          owner: 99,
          market: 1,
          service: 3,
          option: 12,
        )).future,
      ),
      isNull,
    );
    expect(
      f.adapter.requests.where((r) => r.path.contains('/options')).length,
      1,
    );
  });
}
