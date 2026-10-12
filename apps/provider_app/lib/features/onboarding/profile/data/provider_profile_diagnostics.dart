import 'dart:convert';

// Never print arbitrary backend text: it can echo PII or credentials.
const _safeBackendText = {
  'Invalid request',
  'Bad request',
  'Unauthorized',
  'Forbidden',
  'Not found',
  'Conflict',
  'Validation failed',
  'Too many requests',
  'Internal server error',
  'Service unavailable',
};

const _profileFields = {
  'firstName',
  'lastName',
  'nicNumber',
  'passportNumber',
  'dateOfBirth',
  'gender',
  'profilePhoto',
  'bio',
  'availabilityStatus',
  'marketId',
};

/// Called only from the profile remote source's kDebugMode branches.
/// No headers, request values, raw bodies, URLs or exceptions are emitted.
String providerProfileDiagnostic({
  required Map<String, dynamic> payload,
  required int? statusCode,
  Object? errorBody,
}) {
  final backend = <String, String>{};
  if (errorBody is Map) {
    for (final key in ['title', 'detail', 'message']) {
      final value = errorBody[key];
      if (value is String) {
        backend[key] = _safeBackendText.contains(value)
            ? value
            : '[withheld: unrecognized backend text]';
      }
    }
  }
  return jsonEncode({
    'method': 'PUT',
    'path': '/providers/me/profile',
    'statusCode': statusCode,
    ...backend,
    'fields': payload.keys.where(_profileFields.contains).toList(),
  });
}
