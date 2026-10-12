import 'dart:async';

import 'package:bthere_session/bthere_session.dart';

class FakeSessionStorage implements SessionStorage {
  AuthSession? session;
  bool failRead = false;
  int reads = 0;
  int writes = 0;
  int clears = 0;
  Completer<AuthSession?>? pending;
  @override
  Future<AuthSession?> read() async {
    reads++;
    if (failRead) throw StateError('Synthetic storage failure');
    return pending == null ? session : await pending!.future;
  }

  @override
  Future<void> write(AuthSession value) async {
    writes++;
    session = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}

final testNow = DateTime.utc(2030, 1, 2, 12);
AuthSession testSession({bool expired = false}) => AuthSession(
  accessToken: 'synthetic-access',
  refreshToken: 'synthetic-refresh',
  tokenType: 'Bearer',
  expiresAt: testNow.add(Duration(seconds: expired ? 0 : 900)),
);
