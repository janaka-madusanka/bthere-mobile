/// A generic failure at an application/domain boundary.
///
/// The cause may contain sensitive data. Callers must not log it blindly.
final class AppFailure {
  const AppFailure({required this.message, this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;
}
