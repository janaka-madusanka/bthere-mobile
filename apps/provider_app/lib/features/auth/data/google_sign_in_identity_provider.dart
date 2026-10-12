import 'package:google_sign_in/google_sign_in.dart';

import '../domain/google_identity_provider.dart';

/// Owned by app composition. Initialization is lazy and cached once, including
/// failures; no account chooser or silent authentication runs at app startup.
final class GoogleSignInIdentityProvider implements GoogleIdentityProvider {
  GoogleSignInIdentityProvider({required String serverClientId})
    : _serverClientId = serverClientId.trim();

  final String _serverClientId;
  Future<void>? _initialization;

  @override
  Future<String?> requestIdToken() async {
    if (_serverClientId.isEmpty) {
      throw const GoogleIdentityFailure(googleConfigurationFailure);
    }
    try {
      final signIn = GoogleSignIn.instance;
      await (_initialization ??= signIn.initialize(
        serverClientId: _serverClientId,
      ));
      if (!signIn.supportsAuthenticate()) {
        throw const GoogleIdentityFailure(googleConfigurationFailure);
      }
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.trim().isEmpty) {
        throw const GoogleIdentityFailure(googleMissingTokenFailure);
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleIdentityFailure(googleConfigurationFailure);
      }
      throw const GoogleIdentityFailure(googleIdentityOperationFailure);
    } on GoogleIdentityFailure {
      rethrow;
    } catch (_) {
      throw const GoogleIdentityFailure(googleIdentityOperationFailure);
    }
  }
}
