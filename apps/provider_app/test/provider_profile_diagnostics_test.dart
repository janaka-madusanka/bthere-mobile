import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/profile/data/provider_profile_diagnostics.dart';

void main() {
  test('logs only field names and allowlisted backend error text', () {
    final log = providerProfileDiagnostic(
      payload: {
        'firstName': 'PRIVATE NAME',
        'dateOfBirth': 'PRIVATE DOB',
        'bio': 'PRIVATE BIO',
        'Authorization': 'PRIVATE TOKEN',
        'documentKey': 'PRIVATE DOCUMENT',
      },
      statusCode: 500,
      errorBody: {
        'title': 'Internal server error',
        'detail': 'PRIVATE NAME PRIVATE TOKEN',
        'message': 'Service unavailable',
        'errors': {'bio': 'PRIVATE BIO'},
        'accessToken': 'PRIVATE TOKEN',
      },
    );
    expect(jsonDecode(log), {
      'method': 'PUT',
      'path': '/providers/me/profile',
      'statusCode': 500,
      'title': 'Internal server error',
      'detail': '[withheld: unrecognized backend text]',
      'message': 'Service unavailable',
      'fields': ['firstName', 'dateOfBirth', 'bio'],
    });
    expect(log, isNot(contains('PRIVATE')));
    expect(log, isNot(contains('Authorization')));
    expect(log, isNot(contains('documentKey')));
  });

  test('missing HTTP response and non-object bodies remain safe', () {
    for (final body in [
      null,
      'PRIVATE HTML',
      ['PRIVATE BODY'],
    ]) {
      expect(
        jsonDecode(
          providerProfileDiagnostic(
            payload: {'gender': 'FEMALE'},
            statusCode: null,
            errorBody: body,
          ),
        ),
        {
          'method': 'PUT',
          'path': '/providers/me/profile',
          'statusCode': null,
          'fields': ['gender'],
        },
      );
    }
  });
}
