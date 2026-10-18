import 'dart:convert';

import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bthere_session_test.dart' show FakeSecureStore;

void main() {
  final user = SessionUser(
    id: 25,
    marketId: 1,
    username: 'provider',
    status: 'ACTIVE',
    email: 'provider@example.invalid',
    roles: ['SERVICE_PROVIDER'],
    emailVerified: true,
  );
  AuthSession session({SessionUser? user}) => AuthSession(
    accessToken: 'synthetic-access',
    refreshToken: 'synthetic-refresh',
    tokenType: 'Bearer',
    expiresAt: DateTime.utc(2030, 1, 2, 12),
    user: user,
  );

  test(
    'account metadata round trips in the same atomic secure session record',
    () async {
      final driver = FakeSecureStore();
      final storage = SecureSessionStorage(store: driver);
      await storage.write(session(user: user));
      expect(driver.values.length, 1);
      expect(jsonDecode(driver.values.values.single)['user'], user.toJson());
      final restored = (await storage.read())!;
      expect(restored.user!.toJson(), user.toJson());
      expect(restored.expiresAt, session().expiresAt);
      expect(restored.user!.phoneNumber, isNull);
      expect(restored.user!.marketId, 1);
      expect(restored.user!.phoneVerified, isNull);
      expect(restored.user.toString(), isNot(contains(user.email!)));
      expect(() => restored.user!.roles.add('ADMIN'), throwsUnsupportedError);
    },
  );
  test('old secure records without account metadata remain readable', () async {
    final driver = FakeSecureStore();
    final storage = SecureSessionStorage(store: driver);
    await storage.write(session());
    expect(
      jsonDecode(driver.values.values.single).containsKey('user'),
      isFalse,
    );
    expect((await storage.read())!.user, isNull);
  });
  test('missing and null marketId remain readable', () async {
    final legacyUser = Map<String, Object?>.from(user.toJson())
      ..remove('marketId');
    expect(SessionUser.fromJson(legacyUser).marketId, isNull);
    final driver = FakeSecureStore();
    final storage = SecureSessionStorage(store: driver);
    await storage.write(session(user: SessionUser.fromJson(legacyUser)));
    expect((await storage.read())!.user!.marketId, isNull);
  });
  test(
    'malformed stored user never restores a partial authenticated record',
    () async {
      final driver = FakeSecureStore();
      final storage = SecureSessionStorage(store: driver);
      await storage.write(session(user: user));
      final key = driver.values.keys.single;
      final original = jsonDecode(driver.values[key]!) as Map<String, dynamic>;
      for (final malformed in [
        42,
        {},
        {...user.toJson(), 'id': 0},
        for (final marketId in [0, -1, '1', 1.5, true])
          {...user.toJson(), 'marketId': marketId},
        {
          ...user.toJson(),
          'roles': ['SERVICE_PROVIDER', 123],
        },
        {...user.toJson(), 'roles': []},
        {...user.toJson(), 'email': false},
        {...user.toJson(), 'emailVerified': 'true'},
      ]) {
        driver.values[key] = jsonEncode({...original, 'user': malformed});
        expect(await storage.read(), isNull);
      }
    },
  );
  test(
    'failed metadata write preserves the previous complete secure record',
    () async {
      final driver = FakeSecureStore();
      final storage = SecureSessionStorage(store: driver);
      await storage.write(session());
      final previous = driver.values.values.single;
      driver.failWrite = true;
      await expectLater(storage.write(session(user: user)), throwsStateError);
      expect(driver.values.values.single, previous);
      expect((await storage.read())!.user, isNull);
    },
  );
}
