import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_models.dart';

class WalletViewState {
  const WalletViewState({
    required this.snapshot,
    this.request,
    this.intent,
    this.busy = false,
    this.error,
    this.notice,
  });
  final WalletSnapshot snapshot;
  final WalletRequest? request;
  final WalletIntent? intent;
  final bool busy;
  final String? error, notice;
}

final walletControllerProvider =
    AsyncNotifierProvider<WalletController, WalletViewState>(
      WalletController.new,
      dependencies: [
        walletRepositoryProvider,
        walletJournalProvider,
        appSessionStateProvider,
        sessionStorageProvider,
      ],
    );

class WalletController extends AsyncNotifier<WalletViewState> {
  int? _owner;
  int _epoch = 0;
  void _check(int epoch) {
    if (!ref.mounted || epoch != _epoch) {
      throw StateError('Wallet session changed.');
    }
  }

  bool _working = false;
  WalletRepository get _repository => ref.read(walletRepositoryProvider);
  WalletJournal get _journal => ref.read(walletJournalProvider);

  @override
  Future<WalletViewState> build() async {
    final epoch = ++_epoch;
    _working = false;
    ref.onDispose(() => _epoch++);
    final sessionState = await ref.watch(appSessionStateProvider.future);
    _check(epoch);
    if (sessionState != AppSessionState.authenticated) {
      throw StateError('Please sign in to view your wallet.');
    }
    final session = await ref.watch(sessionStorageProvider).read();
    _check(epoch);
    _owner = session?.user?.id;
    final repository = ref.watch(walletRepositoryProvider);
    ref.watch(walletJournalProvider);
    var snapshot = await repository.load();
    _check(epoch);
    final request = _owner == null ? null : await _journal.read(_owner!);
    _check(epoch);
    WalletIntent? intent;
    String? error;
    if (request?.intentId != null) {
      try {
        intent = await repository.intent(request!.intentId!);
      } catch (_) {
        error = 'A previous payment needs a status check. Please retry.';
      }
    }
    _check(epoch);
    if (request?.intentId != null && _owner != null) {
      await _journal.rememberIntent(_owner!, request!.intentId!);
      _check(epoch);
    }
    if (intent?.terminal == true) {
      snapshot = await repository.load();
      _check(epoch);
      await _journal.clear(_owner!);
    }
    return WalletViewState(
      snapshot: snapshot,
      request: intent?.terminal == true ? null : request,
      intent: intent,
      error: error,
    );
  }

  String _message(Object e) => e is NetworkException
      ? e.message
      : e is FormatException
      ? e.message
      : 'Unable to update your wallet. Please retry.';

  Future<void> refresh() async {
    if (_working) return;
    final previous = state.asData?.value;
    if (previous == null) {
      ref.invalidateSelf();
      return;
    }
    await _perform((epoch) async {
      final snapshot = await _repository.load();
      return WalletViewState(
        snapshot: snapshot,
        request: previous.request,
        intent: previous.intent,
        notice: previous.notice,
      );
    });
  }

  Future<void> _perform(
    Future<WalletViewState> Function(int epoch) operation,
  ) async {
    if (_working) return;
    final previous = state.asData?.value;
    if (previous == null) return;
    final epoch = _epoch;
    _working = true;
    state = AsyncData(
      WalletViewState(
        snapshot: previous.snapshot,
        request: previous.request,
        intent: previous.intent,
        busy: true,
      ),
    );
    try {
      final next = await operation(epoch);
      if (ref.mounted && epoch == _epoch) state = AsyncData(next);
    } catch (e) {
      if (!ref.mounted || epoch != _epoch) return;
      final latest = state.asData?.value ?? previous;
      var snapshot = latest.snapshot;
      if (e is NetworkException && e.statusCode == 503) {
        // Re-read settings rather than retaining stale enabled payment controls.
        try {
          snapshot = await _repository.load();
        } catch (_) {}
      }
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          WalletViewState(
            snapshot: snapshot,
            request: latest.request,
            intent: latest.intent,
            error: _message(e),
          ),
        );
      }
    } finally {
      if (epoch == _epoch) _working = false;
    }
  }

  Future<void> addMethod(String type) => _perform((epoch) async {
    final current = state.requireValue;
    final c = current.snapshot.capabilities;
    if (!['CARD', 'BANK_ACCOUNT'].contains(type) ||
        (type == 'CARD' ? !c.cardLinking : !c.bankLinking)) {
      throw const FormatException(
        'This payment method is currently unavailable.',
      );
    }
    final method = await _repository.setup(type);
    _check(epoch);
    return WalletViewState(
      snapshot: await _repository.load(),
      request: current.request,
      intent: current.intent,
      notice: '${method.label} added. This is a test payment method.',
    );
  });

  Future<void> submit(String purpose, WalletMoney amount, int methodId) =>
      _perform((epoch) async {
        final current = state.requireValue;
        if (current.request != null) {
          throw const FormatException('Resolve the previous payment first.');
        }
        if (_owner == null) {
          throw const FormatException(
            'Sign in again to confirm your account before making a payment.',
          );
        }
        final snapshot = current.snapshot;
        final c = snapshot.capabilities;
        final topup = purpose == 'TOPUP';
        final method = snapshot.methods
            .where((m) => m.id == methodId)
            .firstOrNull;
        if (!snapshot.canMove ||
            !amount.validPayment ||
            (topup ? !(c.topups && c.cardLinking) : !c.withdrawals) ||
            method == null ||
            !method.usable ||
            method.card != topup ||
            (!topup && amount.compareTo(snapshot.balance.available) > 0)) {
          throw const FormatException(
            'Check the amount, available balance and payment method.',
          );
        }
        final request = WalletRequest.newRequest(purpose, amount, methodId);
        final owner = _owner!;
        await _journal.write(owner, request);
        _check(epoch);
        state = AsyncData(
          WalletViewState(snapshot: snapshot, request: request, busy: true),
        );
        return _create(request, epoch);
      });

  Future<WalletViewState> _create(WalletRequest request, int epoch) async {
    final owner = _owner!;
    final intent = await _repository.create(request);
    _check(epoch);
    final recorded = request.withIntent(intent.id);
    await _journal.write(owner, recorded);
    _check(epoch);
    await _journal.rememberIntent(owner, intent.id);
    _check(epoch);
    final previous = state.requireValue;
    state = AsyncData(
      WalletViewState(
        snapshot: previous.snapshot,
        request: recorded,
        intent: intent,
        busy: true,
      ),
    );
    return _finish(recorded, intent, epoch);
  }

  Future<WalletViewState> _finish(
    WalletRequest request,
    WalletIntent intent,
    int epoch,
  ) async {
    _check(epoch);
    final owner = _owner!;
    // Server balances remain authoritative even after terminal or failed intents.
    final snapshot = await _repository.load();
    _check(epoch);
    if (intent.terminal) await _journal.clear(owner);
    return WalletViewState(
      snapshot: snapshot,
      request: intent.terminal ? null : request,
      intent: intent,
      notice: intent.status == 'SUCCEEDED'
          ? 'Test payment completed. No real money moved.'
          : intent.status == 'FAILED'
          ? 'Test payment failed. Your balance has been refreshed.'
          : intent.status == 'REFUNDED'
          ? 'Test top-up refunded. Your balance has been refreshed.'
          : 'Payment pending. No success has been confirmed.',
    );
  }

  Future<void> checkPayment() => _perform((epoch) async {
    final request = state.requireValue.request;
    if (request == null || _owner == null) {
      throw const FormatException('No payment to check.');
    }
    if (request.intentId == null) return _create(request, epoch);
    final intent = await _repository.intent(request.intentId!);
    return _finish(request, intent, epoch);
  });

  Future<List<int>> savedIntentIds() async {
    if (_owner == null) return [];
    return _journal.intentIds(_owner!);
  }

  Future<WalletIntent> inspectIntent(int id) async {
    if (id <= 0) throw const FormatException('Enter a valid payment ID.');
    final epoch = _epoch;
    final intent = await _repository.intent(id);
    _check(epoch);
    if (_owner != null) await _journal.rememberIntent(_owner!, intent.id);
    _check(epoch);
    return intent;
  }

  Future<void> refund(int id) => _perform((epoch) async {
    final current = state.requireValue;
    if (current.request != null ||
        !current.snapshot.canMove ||
        !current.snapshot.capabilities.topups ||
        current.snapshot.balance.fundingMode != 'MOCK') {
      throw const FormatException('A test refund is currently unavailable.');
    }
    final intent = await _repository.intent(id);
    _check(epoch);
    if (intent.purpose != 'TOPUP' || intent.status != 'SUCCEEDED') {
      throw const FormatException(
        'Only a successful test top-up can be refunded.',
      );
    }
    final result = await _repository.simulate(id, 'REFUND');
    _check(epoch);
    return WalletViewState(
      snapshot: await _repository.load(),
      intent: result,
      notice: result.status == 'REFUNDED'
          ? 'Test top-up refunded. No real money moved.'
          : 'Refund status has not been confirmed.',
    );
  });

  Future<void> simulate(String outcome) => _perform((epoch) async {
    final current = state.requireValue;
    final request = current.request;
    final method = current.snapshot.methods
        .where((m) => m.id == request?.methodId)
        .firstOrNull;
    final capabilities = current.snapshot.capabilities;
    final permitted = request?.purpose == 'TOPUP'
        ? capabilities.topups && capabilities.cardLinking
        : capabilities.withdrawals;
    if (!permitted ||
        request?.intentId == null ||
        method?.usable != true ||
        current.intent?.status != 'PENDING' ||
        !current.snapshot.canMove) {
      throw const FormatException(
        'This test payment is unavailable. Check its status.',
      );
    }
    final intent = await _repository.simulate(request!.intentId!, outcome);
    return _finish(request, intent, epoch);
  });
}

String walletLoadErrorMessage(Object error) {
  if (error is NetworkException) {
    if (error.statusCode == 401) {
      return 'Please sign in again to view your wallet.';
    }
    if (error.statusCode == 403) {
      return 'Wallet access is unavailable for this account.';
    }
    if (error.statusCode == 503) {
      return 'Wallet services are temporarily unavailable. Please try again shortly.';
    }
    return 'We could not connect to your wallet. Check your connection and try again.';
  }
  if (error is StateError &&
      error.message ==
          'Wallet balance and history are currently unavailable.') {
    return error.message;
  }
  return 'We could not read your wallet details. Please try again.';
}
