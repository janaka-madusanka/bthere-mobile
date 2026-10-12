/// Supplies the current access token without coupling transport to Session.
abstract interface class AccessTokenProvider {
  Future<String?> getAccessToken();
}
