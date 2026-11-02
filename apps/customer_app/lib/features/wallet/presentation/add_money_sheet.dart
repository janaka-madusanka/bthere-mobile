import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../application/customer_wallet_controller.dart';
import '../data/customer_wallet_repository.dart';

class AddMoneySheet extends ConsumerStatefulWidget {
  const AddMoneySheet({
    super.key,
    required this.controller,
    required this.onAddCard,
  });
  final CustomerWalletController controller;
  final Future<void> Function() onAddCard;
  @override
  ConsumerState<AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<AddMoneySheet> {
  final _amount = TextEditingController();
  String _value = '1000';
  int? _method;
  late final int? _owner;
  bool get _active => mounted && c.alive && c.auth.user?.id == _owner;
  bool _busy = true, _locked = false;
  String? _error, _storageKey;
  Map<String, dynamic>? _pending, _intent;
  CustomerWalletController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _owner = c.auth.user?.id;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final store = ref.read(customerMarketSelectionStoreProvider);
      _storageKey =
          'bthere.topup.v1.${Uri.encodeComponent(store.apiScope)}.${c.auth.user!.id}';
      final saved = await store.store.read(_storageKey!);
      if (!_active) return;
      if (saved != null) {
        final record = jsonDecode(saved) as Map<String, dynamic>;
        if (record['key'] is! String ||
            (record['key'] as String).isEmpty ||
            (record['key'] as String).length > 100 ||
            record['methodId'] is! int ||
            (record['methodId'] as int) <= 0 ||
            record['amount'] is! String ||
            !RegExp(r'^\d{1,14}(\.\d{1,2})?$')
                .hasMatch(record['amount'] as String) ||
            walletMinorUnits(record['amount']) <= BigInt.zero) {
          throw const FormatException('Invalid pending top-up');
        }
        _pending = record;
        _value = _pending!['amount'] as String;
        _amount.text = _value;
        _method = _pending!['methodId'] as int;
        _locked = true;
      }
    } catch (_) {
      _error = 'Payment recovery could not be loaded. Close this panel and try again.';
      _locked = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _amountError {
    if (!RegExp(r'^\d{1,14}(\.\d{1,2})?$').hasMatch(_value)) {
      return 'Enter an amount with up to two decimal places.';
    }
    final minor = walletMinorUnits(_value);
    if (minor <= BigInt.zero) return 'Enter an amount greater than zero.';
    if (minor > BigInt.parse('9999999999999999')) {
      return 'This amount is too large.';
    }
    return null;
  }

  Future<void> _submit({bool complete = false}) async {
    if (_busy || !_active) return;
    if (_amountError != null || _method == null) {
      setState(
        () => _error = _amountError ?? 'Choose a saved card to continue.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(customerMarketSelectionStoreProvider).store;
      final repository = c.repository;
      if (complete) {
        final id = _intent!['intentId'] as int;
        _intent = await repository.readTopup(id);
        if (!_active) return;
        if (_intent!['intentId'] != id ||
            walletMinorUnits(_intent!['amount']) != walletMinorUnits(_value) ||
            _intent!['methodId'] != _method) {
          throw const FormatException('Unexpected payment details');
        }
        if (_intent!['status'] == 'PENDING') {
          _intent = await repository.completeTestTopup(id);
        }
      } else {
        // Refresh server capabilities before initiating or recovering a payment.
        await c.load();
        if (!_active) return;
        if (c.error != null ||
            c.data?.active != true ||
            c.data?.capabilities['topups'] != true) {
          throw const WalletFailure(
            'Wallet top-ups are not enabled yet. Please try again later.',
            503,
          );
        }
        _pending ??= {
          'key':
              'topup-${base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)))}',
          'amount': _value,
          'methodId': _method,
        };
        await store.write(_storageKey!, jsonEncode(_pending));
        if (!_active) return;
        _locked = true;
        _intent = await repository.topup(
          _value,
          _method!,
          _pending!['key'] as String,
        );
      }
      if (!_active) return;
      if (walletMinorUnits(_intent!['amount']) != walletMinorUnits(_value) ||
          _intent!['methodId'] != _method) {
        throw const FormatException('Unexpected payment details');
      }
      if (_intent!['status'] != 'PENDING') {
        await store.delete(_storageKey!);
        if (!_active) return;
        await c.load();
        if (!mounted || !_active) return;
        final success = _intent!['status'] == 'SUCCEEDED';
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Test top-up completed. Wallet refreshed.'
                  : 'Top-up ended without adding money.',
            ),
          ),
        );
      }
    } catch (failure) {
      if (_active) {
        _error = failure is WalletFailure ? failure.message : 'The result could not be confirmed. Retry this top-up with the same details.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final cards =
          c.data?.methods
              .where(
                (m) => m['type'] == 'CARD' && m['status'] == 'VERIFIED_MOCK',
              )
              .toList() ??
          [];
      return PopScope(
        canPop: !_busy,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Money',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: CustomerColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Choose an amount to add to your wallet.',
                style: TextStyle(color: CustomerColors.secondaryText),
              ),
              const SizedBox(height: 18),
              const Text(
                'Quick Amounts',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final amount in ['1000', '2000', '5000', '10000'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: amount == '10000' ? 0 : 6,
                        ),
                        child: ChoiceChip(
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          visualDensity: VisualDensity.compact,
                          label: SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                walletMoney(amount).replaceAll('.00', ''),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          selected: _value == amount,
                          onSelected: _busy || _locked
                              ? null
                              : (_) => setState(() {
                                  _value = amount;
                                  _amount.clear();
                                  _error = null;
                                }),
                        ),
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR',
                        style: TextStyle(color: CustomerColors.secondaryText),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                key: const ValueKey('topup-amount'),
                controller: _amount,
                style: const TextStyle(fontSize: 14),
                enabled: !_busy && !_locked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  labelText: 'Custom Amount',
                  prefixText: 'Rs. ',
                  hintText: 'Enter amount',
                ),
                onChanged: (value) => setState(() {
                  _value = value;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pay with',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _method,
                onChanged: (value) => setState(() => _method = value),
                child: Column(
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<int>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          value: card['methodId'] as int,
                          enabled: !_busy && !_locked,
                          selected: _method == card['methodId'],
                          selectedTileColor: const Color(0xFFE8F8F8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: CustomerColors.border,
                            ),
                          ),
                          title: Text(
                            card['displayLabel'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Test payment method',
                            style: TextStyle(fontSize: 11),
                          ),
                          secondary:
                              {
                                'visa',
                                'mastercard',
                              }.contains('${card['brand']}'.toLowerCase())
                              ? SvgPicture.asset(
                                  'assets/icons/payment/${'${card['brand']}'.toLowerCase()}.svg',
                                  width: 30,
                                  height: 20,
                                )
                              : const Icon(
                                  Icons.credit_card,
                                  color: CustomerColors.action,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: _busy || _locked
                    ? null
                    : () async {
                        await widget.onAddCard();
                        if (mounted) setState(() {});
                      },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add new payment method'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Test mode · no real card is charged.',
                style: TextStyle(
                  fontSize: 12,
                  color: CustomerColors.secondaryText,
                ),
              ),
              if (c.data?.capabilities['topups'] != true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Wallet top-ups are not enabled yet.',
                    style: TextStyle(color: CustomerColors.secondaryText),
                  ),
                ),
              if (_pending != null && _intent == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'A previous top-up needs confirmation. Retry with the same amount and card.',
                  ),
                ),
              if (_intent?['status'] == 'PENDING')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Test payment pending. Complete the test result to add test funds.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: CustomerColors.error),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton(
                key: const ValueKey('topup-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed:
                    _busy ||
                        c.data?.capabilities['topups'] != true ||
                        (_locked && _pending == null)
                    ? null
                    : () => _submit(complete: _intent?['status'] == 'PENDING'),
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    _busy
                        ? 'Please wait…'
                        : _intent?['status'] == 'PENDING'
                        ? 'Complete test payment'
                        : _pending != null
                        ? 'Retry same top-up'
                        : _amountError != null
                        ? 'Add money'
                        : 'Add ${walletMoney(_value)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
