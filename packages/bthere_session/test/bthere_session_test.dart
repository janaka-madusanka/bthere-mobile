import 'package:flutter_test/flutter_test.dart';

import 'package:bthere_session/bthere_session.dart';

void main() {
  final expiry = DateTime.utc(2030, 1, 2, 12);
  AuthSession session() => AuthSession(
    accessToken: 'synthetic-access',
    refreshToken: 'synthetic-refresh',
    tokenType: 'Bearer',
    expiresAt: expiry,
  );

  test('model stores credentials and uses an exact UTC expiry boundary', () {
    final value = session();
    expect(value.accessToken.isNotEmpty, isTrue);
    expect(value.refreshToken.isNotEmpty, isTrue);
    expect(value.tokenType, 'Bearer');
    expect(value.expiresAt, expiry);
    expect(
      value.isExpiredAt(expiry.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(value.isExpiredAt(expiry), isTrue);
    expect(value.isExpiredAt(expiry.add(const Duration(seconds: 1))), isTrue);
    final offset = DateTime.parse('2030-01-02T17:30:00+05:30');
    expect(value.isExpiredAt(offset), isTrue);
    final normalized = AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      tokenType: 'Bearer',
      expiresAt: offset,
    );
    expect(normalized.expiresAt.isUtc, isTrue);
    expect(normalized.expiresAt, expiry);
    expect(value.toString(), isNot(contains(value.accessToken)));
    expect(value.toString(), isNot(contains(value.refreshToken)));
  });

  test(
    'rejects empty credentials without including their values in errors',
    () {
      expect(
        () => AuthSession(
          accessToken: ' ',
          refreshToken: 'r',
          tokenType: 'Bearer',
          expiresAt: expiry,
        ),
        throwsArgumentError,
      );
    },
  );

  test('round trip uses one record and UTC expiry', () async {
    final driver = FakeSecureStore();
    final storage = SecureSessionStorage(store: driver);
    await storage.write(session());
    expect(driver.values.length, 1);
    expect(driver.values.values.single, contains(expiry.toIso8601String()));
    final restored = await storage.read();
    expect(restored, isNotNull);
    expect(restored!.accessToken == session().accessToken, isTrue);
    expect(restored.refreshToken == session().refreshToken, isTrue);
    expect(restored.tokenType, 'Bearer');
    expect(restored.expiresAt, expiry);
  });

  test('missing record returns null', () async {
    expect(await SecureSessionStorage(store: FakeSecureStore()).read(), isNull);
  });

  test('clear removes only owned session data and is repeatable', () async {
    final driver = FakeSecureStore()..values['unrelated'] = 'keep';
    final storage = SecureSessionStorage(store: driver);
    await storage.write(session());
    await storage.clear();
    await storage.clear();
    expect(await storage.read(), isNull);
    expect(driver.values, {'unrelated': 'keep'});
  });

  test('corrupt/incomplete records never produce a session', () async {
    final driver = FakeSecureStore();
    final storage = SecureSessionStorage(store: driver);
    await storage.write(session());
    final key = driver.values.keys.single;
    for (final malformed in <String>[
      'not-json',
      'null',
      '[]',
      '{}',
      '{"accessToken":"a","refreshToken":"r","tokenType":"Bearer"}',
      '{"accessToken":"a","refreshToken":"r","tokenType":"Bearer","expiresAt":"bad"}',
      '{"accessToken":"a","refreshToken":"r","tokenType":"Bearer","expiresAt":"2030-02-30T00:00:00.000Z"}',
      '{"accessToken":"a","refreshToken":"r","tokenType":"Bearer","expiresAt":"2030-01-02T12:00:00.000"}',
      '{"accessToken":"","refreshToken":"r","tokenType":"Bearer","expiresAt":"2030-01-02T12:00:00.000Z"}',
      '{"accessToken":123,"refreshToken":"r","tokenType":"Bearer","expiresAt":"2030-01-02T12:00:00.000Z"}',
    ]) {
      driver.values[key] = malformed;
      expect(await storage.read(), isNull);
    }
  });

  test(
    'failed write propagates and preserves complete previous record',
    () async {
      final driver = FakeSecureStore();
      final storage = SecureSessionStorage(store: driver);
      await storage.write(session());
      final before = driver.values.values.single;
      driver.failWrite = true;
      await expectLater(storage.write(session()), throwsStateError);
      expect(driver.values.values.single == before, isTrue);
      expect(await storage.read(), isNotNull);
      await storage.clear();
      await expectLater(storage.write(session()), throwsStateError);
      expect(await storage.read(), isNull);
    },
  );

  test('driver read/clear failures propagate', () async {
    final driver = FakeSecureStore()..failRead = true;
    final storage = SecureSessionStorage(store: driver);
    await expectLater(storage.read(), throwsStateError);
    driver.failDelete = true;
    await expectLater(storage.clear(), throwsStateError);
  });
}

class FakeSecureStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failWrite = false;
  bool failRead = false;
  bool failDelete = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('Synthetic read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Synthetic write failure');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('Synthetic clear failure');
    values.remove(key);
  }
}
