import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';

final class SessionAccessTokenProvider implements AccessTokenProvider {
  SessionAccessTokenProvider(this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SessionStorage _storage;
  final DateTime Function() _now;

  @override
  Future<String?> getAccessToken() async {
    final session = await _storage.read();
    if (session == null || session.isExpiredAt(_now())) return null;
    return session.accessToken;
  }
}
