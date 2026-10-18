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

  Future<Map<String, dynamic>> reviewUploads(int id) async {
    await _pending.catchError((Object _) {});
    final accountKey = await _key(id);
    if (accountKey == null) return {};
    final raw = await storage.read('$accountKey-review-uploads');
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> recordReviewUpload(int id, int typeId, String uploadedKey) {
    final key = _key(id);
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      final accountKey = await key;
      if (accountKey == null) return;
      final storageKey = '$accountKey-review-uploads';
      final raw = await storage.read(storageKey);
      var values = <String, dynamic>{};
      if (raw != null) {
        try {
          values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }
      values['$typeId'] = uploadedKey;
      await storage.write(storageKey, jsonEncode(values));
    });
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
