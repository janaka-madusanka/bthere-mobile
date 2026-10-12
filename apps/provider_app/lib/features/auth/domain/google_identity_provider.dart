import 'package:bthere_common/bthere_common.dart';

/// Mobile identity only. A null result means the user canceled selection.
abstract interface class GoogleIdentityProvider {
  Future<String?> requestIdToken();
}

/// Safe, fixed messages only; never retains plugin exceptions or credentials.
final class GoogleIdentityFailure implements Exception {
  const GoogleIdentityFailure(this.failure);
  final AppFailure failure;
}

const googleConfigurationFailure = AppFailure(
  message: 'Google sign-in is not configured yet. Please continue with email.',
  code: 'GOOGLE_CONFIGURATION_REQUIRED',
);
const googleMissingTokenFailure = AppFailure(
  message: 'Google could not confirm your identity. Please try again.',
  code: 'GOOGLE_ID_TOKEN_MISSING',
);
const googleIdentityOperationFailure = AppFailure(
  message: 'Unable to connect to Google. Please try again.',
  code: 'GOOGLE_IDENTITY_FAILED',
);
