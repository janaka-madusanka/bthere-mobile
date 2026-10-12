import '../models/auth_session.dart';

abstract interface class SessionStorage {
  /// Returns persisted credentials, including expired credentials.
  /// Missing/corrupt data returns null; storage access failures propagate.
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}
