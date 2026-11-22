part of 'wallet_screen.dart';

class _PaymentStatusSheet extends ConsumerStatefulWidget {
  const _PaymentStatusSheet();
  @override
  ConsumerState<_PaymentStatusSheet> createState() =>
      _PaymentStatusSheetState();
}

class _PaymentStatusSheetState extends ConsumerState<_PaymentStatusSheet> {
  final _id = TextEditingController();
  List<int> _ids = [];
  WalletIntent? _intent;
  String? _error;
  bool _busy = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final ids = await ref
          .read(walletControllerProvider.notifier)
          .savedIntentIds();
      if (mounted) setState(() => _ids = ids);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to read saved payment IDs. You can still enter an ID.',
        );
      }
    }
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _check([int? selected]) async {
    if (_busy) return;
    final id = selected ?? int.tryParse(_id.text.trim());
    if (id == null || id <= 0) {
      setState(() => _error = 'Enter a valid payment ID.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _intent = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final controller = ref.read(walletControllerProvider.notifier);
      final pending = ref.read(walletControllerProvider).asData?.value.request;
      WalletIntent? intent;
      if (pending?.intentId == id) {
        await controller.checkPayment();
        final state = ref.read(walletControllerProvider).requireValue;
        if (state.error != null) throw StateError(state.error!);
        intent = state.intent;
      } else {
        intent = await controller.inspectIntent(id);
      }
      if (mounted) setState(() => _intent = intent);
      await _restore();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to find this payment. Check the ID and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refund() async {
    if (_busy || _confirming || _intent == null) return;
    _confirming = true;
    final id = _intent!.id;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Refund top-up?'),
          content: const Text(
            'This removes the top-up amount from your available balance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm refund'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      await ref.read(walletControllerProvider.notifier).refund(id);
      if (!mounted) return;
      final state = ref.read(walletControllerProvider).requireValue;
      setState(() {
        _error = state.error;
        if (state.intent?.id == id) _intent = state.intent;
      });
    } finally {
      _confirming = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider).asData?.value;
    final canRefund =
        _intent?.purpose == 'TOPUP' &&
        _intent?.status == 'SUCCEEDED' &&
        state?.request == null &&
        state?.snapshot.canMove == true &&
        state?.snapshot.capabilities.topups == true &&
        state?.snapshot.balance.fundingMode == 'MOCK';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _walletText('Payment status', 22, bold: true),
            const SizedBox(height: 8),
            const Text(
              'Check a payment ID or select a payment saved on this device.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _id,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Payment ID',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _check(),
            ),
            FilledButton(
              onPressed: _busy || state?.busy == true ? null : _check,
              child: const Text('Check status'),
            ),
            if (_ids.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Saved payment IDs'),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in _ids.take(10))
                    ActionChip(
                      label: Text('#$id'),
                      onPressed: _busy || state?.busy == true
                          ? null
                          : () => _check(id),
                    ),
                ],
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) _WalletMessage(error: true, text: _error!),
            if (_intent != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _walletText('Payment #${_intent!.id}', 16, bold: true),
                    Text(
                      '${_intent!.purpose} · LKR ${_intent!.amount.formatted}',
                    ),
                    Text('Status: ${_intent!.status}'),
                  ],
                ),
              ),
              if (canRefund)
                OutlinedButton(
                  onPressed: _busy || state?.busy == true ? null : _refund,
                  child: const Text('Refund top-up'),
                ),
            ],
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletDetailsSheet extends ConsumerStatefulWidget {
  const _WalletDetailsSheet();
  @override
  ConsumerState<_WalletDetailsSheet> createState() =>
      _WalletDetailsSheetState();
}

class _WalletDetailsSheetState extends ConsumerState<_WalletDetailsSheet> {
  late Future<List<Object>> _details = _load();
  Future<List<Object>> _load() {
    final repository = ref.read(walletRepositoryProvider);
    return Future.wait<Object>([
      repository.wallets(),
      repository.walletCapabilities(),
      repository.reconciliation(),
    ]);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _walletText('Wallet details', 22, bold: true),
          const SizedBox(height: 16),
          FutureBuilder<List<Object>>(
            future: _details,
            builder: (context, state) {
              if (state.hasError) {
                return Column(
                  children: [
                    const Text('Unable to load wallet details.'),
                    TextButton(
                      onPressed: () => setState(() => _details = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (!state.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final wallets = state.data![0] as List<WalletBalance>;
              final capabilities = state.data![1] as WalletCapabilities;
              final reconciliation = state.data![2] as WalletReconciliation;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final wallet in wallets)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: _walletTeal,
                      ),
                      title: Text('${wallet.currency} wallet #${wallet.id}'),
                      subtitle: Text(
                        '${wallet.status}\nAvailable: ${wallet.available.formatted}\nReserved: ${wallet.reserved.formatted}\nPending: ${wallet.pending.formatted}',
                      ),
                    ),
                  if (wallets.isEmpty) const Text('No wallets found.'),
                  const Divider(),
                  Text(
                    reconciliation.balanced
                        ? 'Balance verified against the ledger'
                        : 'Balance verification failed. Payments are blocked.',
                  ),
                  Text('Wallet #${reconciliation.walletId}'),
                  Text(
                    'Ledger available: LKR ${reconciliation.available.formatted}\nLedger reserved: LKR ${reconciliation.reserved.formatted}\nLedger pending: LKR ${reconciliation.pending.formatted}',
                  ),
                  const Divider(),
                  Text(
                    'Card setup: ${capabilities.cardLinking ? "Available" : "Unavailable"}\nBank setup: ${capabilities.bankLinking ? "Available" : "Unavailable"}\nTop-ups: ${capabilities.topups ? "Available" : "Unavailable"}\nWithdrawals: ${capabilities.withdrawals ? "Available" : "Unavailable"}',
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _details = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh details'),
                  ),
                ],
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}
