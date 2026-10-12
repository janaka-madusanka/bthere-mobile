import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_key_value_store.dart';

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    // Public injection name; the driver implementation stays private.
    // ignore: prefer_initializing_formals
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
