import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_request.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';

import 'provider_profile_test.dart' show input;

void main() {
  for (final gender in ProviderGender.values) {
    test(
      '${gender.wireValue} parses and serializes with unchanged remaining fields',
      () {
        expect(ProviderGender.tryParse(gender.wireValue), gender);
        expect(serializeProviderProfile(input(gender: gender)), {
          ...serializeProviderProfile(input()),
          'gender': gender.wireValue,
        });
        expect(
          serializeProviderProfile(input(gender: gender))['gender'],
          isNot(gender.label),
        );
      },
    );
  }

  test('missing, malformed and unconfirmed genders do not default to Male', () {
    for (final value in [
      null,
      'OTHER',
      'male',
      'female',
      'Male',
      'Female',
      1,
      {},
      [],
    ]) {
      expect(ProviderGender.tryParse(value), isNull);
    }
  });
}
