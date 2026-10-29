import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';

final class SessionAccessTokenProvider implements AccessTokenProvider {
  SessionAccessTokenProvider(
    this._storage, {
    DateTime Function()? now,
    this.refreshSession,
  }) : _now = now ?? DateTime.now;

  final SessionStorage _storage;
  final DateTime Function() _now;
  final Future<AuthSession?> Function(AuthSession)? refreshSession;

  @override
  Future<String?> getAccessToken() async {
    final session = await _storage.read();
    if (session == null) return null;
    if (session.isExpiredAt(_now())) {
      return (await refreshSession?.call(session))?.accessToken;
    }
    return session.accessToken;
  }
}
