import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/services/application/service_draft_store.dart';

import 'support/fake_session_storage.dart';

class MemoryDraftStorage implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

AuthSession account(int id) => AuthSession(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2030),
  user: SessionUser(
    id: id,
    username: 'test-$id',
    status: 'ACTIVE',
    roles: ['SERVICE_PROVIDER'],
  ),
);

void main() {
  test('restores latest incomplete selection and experience across store instances', () async {
    final session = FakeSessionStorage()..session = account(1);
    final storage = MemoryDraftStorage();
    final store = ServiceDraftStore(session, storage);
    final first = store.write(3, {1}, '2');
    final second = store.write(3, {1, 2}, '2.5');
    await Future.wait([first, second]);
    final restored = await ServiceDraftStore(session, storage).read(3);
    expect(restored?['selected'], [1, 2]);
    expect(restored?['experience'], '2.5');
    expect(await store.read(4), isNull);
  });
  test(
    'isolates accounts and clears only the submitted service draft',
    () async {
      final session = FakeSessionStorage()..session = account(1);
      final store = ServiceDraftStore(session, MemoryDraftStorage());
      await store.write(3, {1}, '2');
      await store.write(4, {2}, '3');
      session.session = account(2);
      expect(await store.read(3), isNull);
      session.session = account(1);
      await store.clear(3);
      expect(await store.read(3), isNull);
      expect((await store.read(4))?['selected'], [2]);
    },
  );
  test('ignores corrupt draft JSON', () async {
    final session = FakeSessionStorage()..session = account(1);
    final storage = MemoryDraftStorage()
      ..values['service-draft-v1-1-3'] = '{broken';
    expect(await ServiceDraftStore(session, storage).read(3), isNull);
  });
}
