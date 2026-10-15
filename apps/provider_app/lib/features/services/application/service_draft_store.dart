import 'dart:convert';

import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';

final serviceDraftStoreProvider = Provider<ServiceDraftStore>(
  (ref) => ServiceDraftStore(
    ref.watch(sessionStorageProvider),
    const FlutterSecureKeyValueStore(),
  ),
  dependencies: [sessionStorageProvider],
);

class ServiceDraftStore {
  ServiceDraftStore(this.session, this.store);
  final SessionStorage session;
  final SecureKeyValueStore store;
  Future<void> _pending = Future.value();
  Future<String?> _key(int service) async {
    final user = (await session.read())?.user;
    return user == null ? null : 'service-draft-v1-${user.id}-$service';
  }

  Future<Map<String, dynamic>?> read(int service) async {
    await _pending;
    final key = await _key(service);
    if (key == null) return null;
    final raw = await store.read(key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['experience'] is! String ||
          value['selected'] is! List ||
          (value['selected'] as List).any((id) => id is! int || id <= 0)) {
        return null;
      }
      return value;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(int service, Set<int> selected, String experience) {
    final accountKey = _key(service);
    final snapshot = jsonEncode({
      'selected': selected.toList(),
      'experience': experience,
    });
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      final key = await accountKey;
      if (key != null) await store.write(key, snapshot);
    });
  }

  Future<void> clear(int service) =>
      _pending = _pending.catchError((Object _) {}).then((_) async {
        final key = await _key(service);
        if (key != null) await store.delete(key);
      });
}
