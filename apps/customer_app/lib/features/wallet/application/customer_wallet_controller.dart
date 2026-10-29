import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../data/customer_wallet_repository.dart';

final customerWalletRepositoryProvider = Provider<CustomerWalletRepository>(
  (ref) => CustomerWalletRepository(ref.watch(customerAuthServiceProvider)),
  dependencies: [customerAuthServiceProvider],
);
final customerWalletProvider = Provider.autoDispose<CustomerWalletController>(
  (ref) {
    final c = CustomerWalletController(
      ref.watch(customerWalletRepositoryProvider),
      ref.watch(customerAuthControllerProvider),
    );
    ref.onDispose(c.dispose);
    return c;
  },
  dependencies: [
    customerWalletRepositoryProvider,
    customerAuthControllerProvider,
  ],
);

class CustomerWalletController extends ChangeNotifier {
  CustomerWalletController(this.repository, this.auth) {
    auth.addListener(_sync);
    _sync();
  }
  final CustomerWalletRepository repository;
  final CustomerAuthController auth;
  WalletSnapshot? data;
  final entries = <Map<String, dynamic>>[];
  String? error, pageError;
  bool loading = false, working = false, loadingMore = false, _disposed = false;
  int? _owner;
  int _epoch = 0, page = 0;
  bool last = true;
  bool get alive =>
      !_disposed &&
      _owner != null &&
      _owner == auth.user?.id &&
      auth.stage == CustomerAuthStage.authenticated;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    if (auth.stage != CustomerAuthStage.authenticated ||
        _owner != auth.user?.id) {
      _epoch++;
      data = null;
      entries.clear();
      error = pageError = null;
      loading = working = loadingMore = false;
      _owner = auth.stage == CustomerAuthStage.authenticated
          ? auth.user?.id
          : null;
      if (_owner != null) {
        load();
      } else {
        _notify();
      }
    }
  }

  Future<void> load() async {
    if (!alive || loading || working) return;
    final epoch = ++_epoch;
    loading = true;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final result = await repository.load();
      if (!alive || epoch != _epoch) return;
      data = result;
      entries
        ..clear()
        ..addAll(result.history.entries);
      page = 0;
      last = result.history.last;
      pageError = null;
    } catch (failure) {
      if (alive && epoch == _epoch) {
        error = 'Your wallet could not be refreshed. Please try again.';
      }
      if (failure is CustomerAuthFailure && failure.status == 401) {
        await auth.restore();
      }
    } finally {
      if (alive && epoch == _epoch) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> more() async {
    if (!alive || loading || working || loadingMore || last) return;
    final epoch = _epoch;
    loadingMore = true;
    pageError = null;
    _notify();
    try {
      final result = await repository.history(page + 1);
      if (!alive || epoch != _epoch) return;
      final known = entries.map((e) => e['entryId']).toSet();
      entries.addAll(result.entries.where((e) => known.add(e['entryId'])));
      page = result.number;
      last = result.last;
    } catch (_) {
      if (alive && epoch == _epoch) {
        pageError = 'More payments could not be loaded. Please retry.';
      }
    } finally {
      if (alive && epoch == _epoch) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> openOrLink([String? type]) async {
    if (!alive ||
        loading ||
        working ||
        data == null ||
        !data!.balanced ||
        error != null) {
      return;
    }
    if (type != null &&
        (!data!.active ||
            data!.capabilities[type == 'CARD'
                    ? 'cardLinking'
                    : 'bankLinking'] !=
                true)) {
      return;
    }
    final epoch = ++_epoch;
    working = true;
    error = null;
    _notify();
    try {
      if (type == null) {
        await repository.open();
      } else {
        await repository.linkTestMethod(type);
      }
    } catch (_) {
      if (alive && epoch == _epoch) error = 'The change could not be confirmed. Refresh your wallet before trying again.';
    } finally {
      if (alive && epoch == _epoch) {
        working = false;
        _notify();
      }
    }
    if (alive && epoch == _epoch && error == null) await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    auth.removeListener(_sync);
    super.dispose();
  }
}
