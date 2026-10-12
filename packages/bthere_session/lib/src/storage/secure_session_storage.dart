import 'dart:convert';

import '../models/auth_session.dart';
import '../models/session_user.dart';
import 'secure_key_value_store.dart';
import 'session_storage.dart';

final class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage({required SecureKeyValueStore store})
    // Public injection name; the driver implementation stays private.
    // ignore: prefer_initializing_formals
    : _store = store;

  static const _key = 'bthere.session.credentials';
  final SecureKeyValueStore _store;

  @override
  Future<AuthSession?> read() async {
    // Keep platform access outside the corruption handler: failures propagate.
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      final type = data['tokenType'];
      final expiry = data['expiresAt'];
      if (access is! String ||
          refresh is! String ||
          type is! String ||
          expiry is! String ||
          !expiry.endsWith('Z')) {
        return null;
      }
      final parsed = DateTime.tryParse(expiry);
      // Reject permissive DateTime overflow parsing and noncanonical timestamps.
      if (parsed == null || parsed.toUtc().toIso8601String() != expiry) {
        return null;
      }
      return AuthSession(
        accessToken: access,
        refreshToken: refresh,
        tokenType: type,
        expiresAt: parsed,
        user: data['user'] == null ? null : SessionUser.fromJson(data['user']),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) => _store.write(
    _key,
    jsonEncode({
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'tokenType': session.tokenType,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      if (session.user != null) 'user': session.user!.toJson(),
    }),
  );

  @override
  Future<void> clear() => _store.delete(_key);
}
