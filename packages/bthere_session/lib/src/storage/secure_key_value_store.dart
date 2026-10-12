/// Minimal driver for secure session persistence, not general app storage.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  /// Replaces one complete value. Failure must never publish a partial value.
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
