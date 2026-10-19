part of 'wallet_screen.dart';

class _MethodsSheet extends ConsumerWidget {
  const _MethodsSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(walletControllerProvider).asData?.value;
    if (value == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final c = value.snapshot.capabilities;
    final controller = ref.read(walletControllerProvider.notifier);
    final enabled = !value.busy;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _walletText('Payment & Withdrawal Methods', 20, bold: true),
            const SizedBox(height: 8),
            const Text(
              'Current setup creates test methods only. No card number or bank details are required.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            for (final method in value.snapshot.methods)
              _MethodRow(method: method, scale: 1),
            if (value.snapshot.methods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No saved methods.'),
              ),
            if (value.error != null)
              _WalletMessage(text: value.error!, error: true),
            if (value.notice != null) _WalletMessage(text: value.notice!),
            if (value.busy) const LinearProgressIndicator(),
            if (c.cardLinking)
              OutlinedButton.icon(
                onPressed: enabled ? () => controller.addMethod('CARD') : null,
                icon: const Icon(Icons.credit_card),
                label: const Text('Add test card'),
              ),
            if (c.bankLinking)
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => controller.addMethod('BANK_ACCOUNT')
                    : null,
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Add test bank account'),
              ),
            if (!c.cardLinking && !c.bankLinking)
              const _WalletMessage(
                text: 'The server has disabled card and bank account setup. Refresh availability after your payment service is enabled.',
              ),
            TextButton.icon(
              onPressed: value.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh availability'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.topup});
  final bool topup;
  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  int? _methodId;
  String? _validation;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(WalletViewState value) async {
    WalletMoney amount;
    try {
      amount = WalletMoney.parse(_amount.text.trim());
      if (!amount.validPayment) {
        throw const FormatException(
          'Enter an amount greater than zero, up to LKR 99,999,999,999,999.99.',
        );
      }
      if (!widget.topup &&
          amount.compareTo(value.snapshot.balance.available) > 0) {
        throw const FormatException(
          'The amount exceeds your available balance.',
        );
      }
      if (_methodId == null) {
        throw const FormatException('Select a payment method.');
      }
    } on FormatException catch (e) {
      setState(() => _validation = e.message);
      return;
    }
    setState(() => _validation = null);
    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(walletControllerProvider.notifier)
        .submit(widget.topup ? 'TOPUP' : 'WITHDRAWAL', amount, _methodId!);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(walletControllerProvider).asData?.value;
    if (value == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final methods = value.snapshot.methods
        .where((m) => m.usable && m.card == widget.topup)
        .toList();
    if (_methodId != null && !methods.any((m) => m.id == _methodId)) {
      _methodId = null;
    }
    final caps = value.snapshot.capabilities;
    final enabled =
        value.snapshot.canMove &&
        !value.busy &&
        value.request == null &&
        (widget.topup ? caps.topups && caps.cardLinking : caps.withdrawals);
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
            _walletText(
              widget.topup ? 'Top Up Wallet' : 'Withdraw',
              22,
              bold: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Test payment only. No real card charge or bank payout will occur.',
              style: TextStyle(fontSize: 12, color: _walletTeal),
            ),
            const SizedBox(height: 12),
            Text(
              'Available: LKR ${value.snapshot.balance.available.formatted}',
            ),
            if (widget.topup && (!caps.topups || !caps.cardLinking)) ...[
              const _WalletMessage(
                text: 'Top-ups are currently disabled by the payment service. Refresh availability after the service is enabled.',
              ),
              TextButton.icon(
                onPressed: value.busy
                    ? null
                    : () =>
                          ref.read(walletControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh availability'),
              ),
            ],
            const SizedBox(height: 16),
            if (value.request == null) ...[
              TextField(
                controller: _amount,
                enabled: !value.busy,
                key: const ValueKey('wallet-payment-amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (LKR)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _methodId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.topup ? 'Test card' : 'Test bank account',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final method in methods)
                    DropdownMenuItem(
                      value: method.id,
                      child: Text(
                        method.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: value.busy
                    ? null
                    : (id) => setState(() => _methodId = id),
              ),
              if (methods.isEmpty)
                TextButton(
                  onPressed: value.busy
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => const _MethodsSheet(),
                        ),
                  child: Text(
                    widget.topup
                        ? 'Add a test card first'
                        : 'Add a test bank account first',
                  ),
                ),
              if (_validation != null)
                _WalletMessage(text: _validation!, error: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: enabled && methods.isNotEmpty
                    ? () => _submit(value)
                    : null,
                child: Text(
                  value.busy
                      ? 'Please wait…'
                      : widget.topup
                      ? 'Create test top-up'
                      : 'Create test withdrawal',
                ),
              ),
            ] else
              _PendingPayment(value: value),
            if (value.error != null)
              _WalletMessage(text: value.error!, error: true),
            if (value.notice != null) _WalletMessage(text: value.notice!),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
