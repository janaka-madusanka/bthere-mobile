import 'dart:convert';

import '../../discovery/data/customer_market_selection_store.dart';

/// References only, isolated by API environment and signed-in account.
class CustomerRequestRecoveryStore {
  CustomerRequestRecoveryStore(this.selection, this.userId);
  final CustomerMarketSelectionStore selection;
  final int userId;
  String get _key =>
      'bthere.customer.requests.v1.${Uri.encodeComponent(selection.apiScope)}.$userId';
  Future<Set<int>> read() async {
    final raw = await selection.store.read(_key);
    if (raw == null) return {};
    final values = jsonDecode(raw);
    if (values is! List) throw const FormatException('Invalid saved requests');
    return values.whereType<int>().where((id) => id > 0).toSet();
  }

  Future<void> save(Set<int> ids) =>
      selection.store.write(_key, jsonEncode(ids.toList()));
  Future<void> saveMethod(int id, String method) =>
      selection.store.write('$_key.method.$id', method);
  Future<void> saveJobRequest(int jobId, int requestId) =>
      selection.store.write('$_key.job.$jobId', '$requestId');
  Future<int?> requestForJob(int jobId) async {
    final id = int.tryParse(
      await selection.store.read('$_key.job.$jobId') ?? '',
    );
    return id != null && id > 0 ? id : null;
  }

  Future<String?> method(int id) => selection.store.read('$_key.method.$id');
  Future<bool> methodChangePending(int id) async =>
      await selection.store.read('$_key.methodPending.$id') == 'true';
  Future<void> markMethodChange(int id, bool pending) => pending
      ? selection.store.write('$_key.methodPending.$id', 'true')
      : selection.store.delete('$_key.methodPending.$id');
  Future<int> cursor() async =>
      int.tryParse(await selection.store.read('$_key.event') ?? '') ?? 0;
  Future<void> saveCursor(int id) =>
      selection.store.write('$_key.event', '$id');
  Future<bool> uncertain(int id) async =>
      (await selection.store.read('$_key.payment.$id'))
          ?.startsWith('pending') ==
      true;
  Future<String?> paymentBaseline(int id) =>
      selection.store.read('$_key.payment.$id');
  Future<void> markPayment(int id, bool pending, {String? previousStatus}) =>
      pending
      ? selection.store.write(
          '$_key.payment.$id',
          'pending:${previousStatus ?? 'UNKNOWN'}',
        )
      : selection.store.delete('$_key.payment.$id');
  // Per-key serialization prevents creation and event recovery losing IDs.
  static final _storeWrites = Expando<Map<String, Future<void>>>();
  Map<String, Future<void>> get _writes => _storeWrites[selection.store] ??= {};
  Future<void> remember(int id) {
    final pending = (_writes[_key] ?? Future<void>.value()).catchError(
      (Object _) {},
    );
    final operation = pending.then((_) async {
      final ids = await read();
      ids.add(id);
      await save(ids);
    });
    _writes[_key] = operation;
    return operation;
  }
}
