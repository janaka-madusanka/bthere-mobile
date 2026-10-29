import 'package:bthere_session/bthere_session.dart';

/// Device-local preference, scoped to both the API environment and account.
/// Only the confirmed ID is stored; current market metadata comes from /markets.
class CustomerMarketSelectionStore {
  CustomerMarketSelectionStore(this.store, {required this.apiScope});
  final SecureKeyValueStore store;
  final String apiScope;
  Future<void> _pending = Future.value();

  String _key(int userId) {
    if (userId <= 0) throw ArgumentError('Invalid account ID');
    return 'bthere.customer.market.v1.${Uri.encodeComponent(apiScope)}.$userId';
  }

  Future<int?> read(int userId) async {
    await _pending;
    final value = await store.read(_key(userId));
    final id = value == null ? null : int.tryParse(value);
    return id != null && id > 0 ? id : null;
  }

  Future<void> save(int userId, int marketId) {
    if (marketId <= 0) throw ArgumentError('Invalid market ID');
    final key = _key(userId);
    final operation = _pending.then((_) => store.write(key, '$marketId'));
    // Keep later writes usable after a failure without hiding it from its caller.
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
