import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/provider_home_widgets.dart';
import '../application/wallet_controller.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_models.dart';

part 'wallet_widgets.dart';
part 'wallet_sheets.dart';
part 'wallet_details.dart';

const _walletInk = Color(0xFF0B3037);
const _walletMuted = Color(0xFF687B83);
const _walletTeal = Color(0xFF008F95);

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with WidgetsBindingObserver {
  bool _visible = false;
  bool _first = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible && !_first) {
      Future.microtask(() {
        if (mounted) ref.read(walletControllerProvider.notifier).refresh();
      });
    }
    _visible = visible;
    _first = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) {
      ref.read(walletControllerProvider.notifier).refresh();
    }
  }

  Future<void> _payment(bool topup) async {
    final value = ref.read(walletControllerProvider).asData?.value;
    if (value == null || value.busy) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _PaymentSheet(topup: topup),
    );
  }

  Future<void> _methods() async => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _MethodsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final scale = (MediaQuery.sizeOf(context).width / 430).clamp(.7, 1.0);
    final controller = ref.read(walletControllerProvider.notifier);
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'PublicSans',
          bodyColor: _walletInk,
          displayColor: _walletInk,
        ),
      ),
      child: DecoratedBox(
        decoration: homeGradient,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeScale(child: HomeHeader()),
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: state.when(
                    loading: () => const Center(
                      child: BThereLoadingState(label: 'Loading wallet'),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: BThereStateView(
                          title: 'Unable to load wallet',
                          message: walletLoadErrorMessage(error),
                          action: BThereButton(
                            label: 'Retry',
                            onPressed: () =>
                                ref.invalidate(walletControllerProvider),
                          ),
                        ),
                      ),
                    ),
                    data: (value) {
                      final snapshot = value.snapshot;
                      final caps = snapshot.capabilities;
                      final starter =
                          snapshot.balance.fundingMode == 'UNFUNDED';
                      final canAct =
                          snapshot.canMove &&
                          !value.busy &&
                          value.request == null;
                      final groups = _groupEntries(snapshot.history.entries)
                          .take(4)
                          .toList();
                      return RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: ListView(
                          key: const PageStorageKey('wallet-scroll'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(14 * scale),
                          children: [
                            _BalanceCard(
                              balance: snapshot.balance,
                              scale: scale,
                              compact: starter,
                              onTopup: !value.busy
                                  ? () => _payment(true)
                                  : null,
                            ),
                            if (!snapshot.balanced)
                              const _WalletMessage(
                                error: true,
                                text: 'Wallet balance verification failed. Payments are blocked. Please contact support.',
                              ),
                            if (snapshot.balance.status != 'ACTIVE')
                              const _WalletMessage(
                                error: true,
                                text: 'This wallet is inactive. Payments are unavailable.',
                              ),
                            if (value.error != null)
                              _WalletMessage(error: true, text: value.error!),
                            if (value.notice != null)
                              _WalletMessage(text: value.notice!),
                            if (value.busy)
                              const LinearProgressIndicator(minHeight: 2),
                            SizedBox(height: 10 * scale),
                            if ((!starter && caps.topups && caps.cardLinking) ||
                                caps.withdrawals)
                              Row(
                                children: [
                                  if (!starter &&
                                      caps.topups &&
                                      caps.cardLinking)
                                    Expanded(
                                      child: _WalletAction(
                                        label: 'Top Up Wallet',
                                        icon: Icons.add_circle_outline,
                                        onTap: canAct
                                            ? () => _payment(true)
                                            : null,
                                        scale: scale,
                                      ),
                                    ),
                                  if (!starter &&
                                      caps.topups &&
                                      caps.cardLinking &&
                                      caps.withdrawals)
                                    const SizedBox(width: 10),
                                  if (caps.withdrawals)
                                    Expanded(
                                      child: _WalletAction(
                                        label: 'Withdraw',
                                        icon: Icons.east,
                                        onTap: canAct
                                            ? () => _payment(false)
                                            : null,
                                        scale: scale,
                                      ),
                                    ),
                                ],
                              ),
                            if (!caps.topups && !caps.withdrawals)
                              const _WalletMessage(
                                text: 'Top-ups and withdrawals are currently unavailable.',
                              ),
                            if (value.request != null)
                              _PendingPayment(value: value),
                            SizedBox(height: 12 * scale),
                            _PaymentMethods(
                              snapshot: snapshot,
                              scale: scale,
                              onManage: value.busy ? null : _methods,
                            ),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    useSafeArea: true,
                                    builder: (_) => const _PaymentStatusSheet(),
                                  ),
                                  icon: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Payment status'),
                                ),
                                TextButton.icon(
                                  onPressed: () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    useSafeArea: true,
                                    builder: (_) => const _WalletDetailsSheet(),
                                  ),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Wallet details'),
                                ),
                              ],
                            ),
                            SizedBox(height: 6 * scale),
                            Row(
                              children: [
                                Expanded(
                                  child: _walletText(
                                    'Recent Transactions',
                                    15 * scale,
                                    bold: true,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const WalletHistoryScreen(),
                                    ),
                                  ),
                                  child: Text(
                                    'View All  ›',
                                    style: TextStyle(
                                      fontSize: 11 * scale,
                                      color: _walletTeal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: _panelDecoration(),
                              child: groups.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'No transactions yet.',
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (final group in groups)
                                          _TransactionRow(
                                            entries: group,
                                            scale: scale,
                                          ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletHistoryScreen extends ConsumerStatefulWidget {
  const WalletHistoryScreen({super.key});
  @override
  ConsumerState<WalletHistoryScreen> createState() =>
      _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends ConsumerState<WalletHistoryScreen> {
  final _entries = <WalletEntry>[];
  bool _loading = false, _last = false;
  int _page = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final page = reset ? 0 : _page;
    try {
      final history = await ref
          .read(walletRepositoryProvider)
          .history(page: page);
      if (!mounted) return;
      setState(() {
        if (reset) _entries.clear();
        final ids = _entries.map((e) => e.id).toSet();
        _entries.addAll(history.entries.where((e) => ids.add(e.id)));
        _page = history.page + 1;
        _last = history.last;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load transactions. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet Transactions')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final group in _groupEntries(_entries))
            _TransactionRow(entries: group, scale: 1),
          if (_entries.isEmpty && !_loading && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No transactions yet.'),
            ),
          if (_error != null) _WalletMessage(error: true, text: _error!),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!_last || _error != null)
            TextButton(
              onPressed: _load,
              child: Text(_error == null ? 'Load more' : 'Retry'),
            ),
        ],
      ),
    ),
  );
}
