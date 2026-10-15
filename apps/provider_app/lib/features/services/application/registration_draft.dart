import 'dart:convert';

import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';

final registrationDraftStoreProvider = Provider<RegistrationDraftStore>(
  (ref) => RegistrationDraftStore(
    ref.watch(sessionStorageProvider),
    const FlutterSecureKeyValueStore(),
  ),
  dependencies: [sessionStorageProvider],
);

/// UI drafts never imply backend persistence or approval.
class RegistrationDraftStore {
  RegistrationDraftStore(this.session, this.storage);
  final SessionStorage session;
  final SecureKeyValueStore storage;
  Future<void> _pending = Future.value();
  Future<String?> _key(int id) async {
    final user = (await session.read())?.user;
    return user == null ? null : 'registration-ui-v1-${user.id}-$id';
  }

  Future<Map<String, dynamic>> read(int id) async {
    await _pending.catchError((Object _) {});
    final key = await _key(id);
    if (key == null) return {};
    final raw = await storage.read(key);
    if (raw == null) return {};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> write(int id, Map<String, dynamic> value) {
    final key = _key(id), snapshot = jsonEncode(value);
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      final accountKey = await key;
      if (accountKey == null) throw StateError('Sign in to save progress.');
      await storage.write(accountKey, snapshot);
    });
  }
}
