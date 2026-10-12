import 'package:bthere_common/bthere_common.dart';

/// Presentation state holds safe domain results, never request credentials.
final class AuthSubmissionState<T> {
  const AuthSubmissionState({this.loading = false, this.value, this.failure});
  final bool loading;
  final T? value;
  final AppFailure? failure;
}

AppFailure safeAuthFailure(AppFailure failure) =>
    AppFailure(message: failure.message, code: failure.code);

const unexpectedAuthFailure = AppFailure(
  message: 'Unable to complete this request. Please try again.',
  code: 'AUTH_UI_OPERATION_FAILED',
);
