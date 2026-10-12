import 'package:bthere_common/bthere_common.dart';

enum NetworkExceptionKind {
  connection,
  timeout,
  cancelled,
  badResponse,
  unknown,
}

/// Contains safe transport metadata only, never raw requests or plugin causes.
final class NetworkException implements Exception {
  const NetworkException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.backendCode,
  });

  final NetworkExceptionKind kind;
  final String message;
  final int? statusCode;
  final String? backendCode;

  /// Repositories map transport failures and return Result to presentation.
  AppFailure toAppFailure() => AppFailure(
    message: message,
    code: backendCode ?? 'NETWORK_${kind.name.toUpperCase()}',
  );

  // Deliberately omit metadata supplied by callers.
  @override
  String toString() => 'NetworkException(${kind.name})';
}
