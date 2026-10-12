import 'package:dio/dio.dart';

import 'network_exception.dart';

// Untrusted free-text responses can echo tokens, passwords, or personal data.
// Only known generic text/codes are exposed until a global error contract exists.
const _safeMessages = {
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
const _safeCodes = {
  'BAD_REQUEST',
  'UNAUTHORIZED',
  'FORBIDDEN',
  'NOT_FOUND',
  'CONFLICT',
  'VALIDATION_ERROR',
  'RATE_LIMITED',
  'INTERNAL_SERVER_ERROR',
  'SERVICE_UNAVAILABLE',
};

NetworkException normalizeDioException(DioException error) {
  final kind = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => NetworkExceptionKind.timeout,
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate => NetworkExceptionKind.connection,
    DioExceptionType.cancel => NetworkExceptionKind.cancelled,
    DioExceptionType.badResponse => NetworkExceptionKind.badResponse,
    DioExceptionType.unknown => NetworkExceptionKind.unknown,
  };
  var message = switch (kind) {
    NetworkExceptionKind.connection => 'Unable to connect to the server.',
    NetworkExceptionKind.timeout => 'The request timed out.',
    NetworkExceptionKind.cancelled => 'The request was cancelled.',
    NetworkExceptionKind.badResponse =>
      'The server could not complete the request.',
    NetworkExceptionKind.unknown => 'The request could not be completed.',
  };
  String? code;
  final data = error.response?.data;
  if (kind == NetworkExceptionKind.badResponse &&
      data is Map<String, dynamic>) {
    final backendMessage = data['message'];
    final backendCode = data['code'];
    if (backendMessage is String && _safeMessages.contains(backendMessage)) {
      message = backendMessage;
    }
    if (backendCode is String && _safeCodes.contains(backendCode)) {
      code = backendCode;
    }
  }
  return NetworkException(
    kind: kind,
    message: message,
    statusCode: error.response?.statusCode,
    backendCode: code,
  );
}
