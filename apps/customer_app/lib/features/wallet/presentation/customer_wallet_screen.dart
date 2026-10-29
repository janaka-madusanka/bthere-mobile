import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../../../app/customer_providers.dart';
import '../../../app/widgets/customer_top_bar.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../../discovery/presentation/customer_bottom_navigation.dart';
import '../../profile/application/customer_profile_controller.dart';
import '../application/customer_wallet_controller.dart';
import '../data/customer_wallet_repository.dart';
import 'add_test_card_dialog.dart';
import 'add_money_sheet.dart';

class CustomerWalletScreen extends ConsumerStatefulWidget {
  const CustomerWalletScreen({super.key});
  @override
  ConsumerState<CustomerWalletScreen> createState() =>
      _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends ConsumerState<CustomerWalletScreen> {
  bool _hidden = false;
  final _historyKey = GlobalKey();

  Future<void> _history() async {
    final c = ref.read(customerWalletProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => Theme(
          data: CustomerTheme.light(),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Scaffold(
              backgroundColor: CustomerColors.surface,
              bottomNavigationBar: const CustomerBottomNavigation(
                selected: CustomerNavigationTab.wallet,
              ),
              body: Column(
                children: [
                  CustomerTopBar(
                    photo: safeImageUrl(
                      ref
                          .read(customerProfileControllerProvider)
                          .profile
                          ?.details
                          .profilePhoto,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to wallet',
                          onPressed: () => Navigator.pop(pageContext),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'Payment history',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: c.load,
                      child: ListView(
                        key: const ValueKey('wallet-full-history'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          const Text(
                            'Your payments and wallet top-ups',
                            style: TextStyle(
                              color: CustomerColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (c.loading) const LinearProgressIndicator(),
                          if (c.error != null)
                            _WalletMessage(message: c.error!, action: c.load),
                          if (!c.loading &&
                              c.error == null &&
                              c.entries.isEmpty)
                            const _EmptyWalletPanel(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              message: 'Your payments and wallet top-ups will appear here.',
                            ),
                          if (c.alive) ..._transactions(c, all: true),
                          if (c.pageError != null)
                            _WalletMessage(
                              message: c.pageError!,
                              action: c.more,
                            ),
                          if (!c.last && c.alive)
                            OutlinedButton.icon(
                              key: const ValueKey('wallet-history-load-more'),
                              onPressed: c.loading || c.loadingMore
                                  ? null
                                  : c.more,
                              icon: const Icon(Icons.expand_more),
                              label: Text(
                                c.loadingMore
                                    ? 'Loading…'
                                    : 'Show more payments',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _methods(CustomerWalletController c) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheetContext) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payment methods',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close payment methods',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Your saved cards',
                style: TextStyle(
                  fontSize: 13,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              if (c.loading || c.working) const LinearProgressIndicator(),
              if (c.error != null)
                _WalletMessage(message: c.error!, action: c.load),
              if (c.data?.methods.any((m) => m['type'] == 'CARD') != true)
                const _EmptyWalletPanel(
                  icon: Icons.credit_card_outlined,
                  title: 'No saved cards',
                  message: 'Add a card to get started.',
                ),
              for (final method
                  in c.data?.methods.where((m) => m['type'] == 'CARD') ??
                      <Map<String, dynamic>>[])
                _savedCard(method, c, details: false),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: c.loading || c.working || !c.alive
                    ? null
                    : () => _addCard(c),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text('Add new payment method'),
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 17,
                    color: CustomerColors.action,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Test cards only. No real card is linked or charged.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCard(CustomerWalletController c) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AddTestCardDialog(
      now: ref.read(customerClockProvider),
      unavailableReason: c.data?.balance == null
          ? 'Open your wallet before adding a card.'
          : c.data?.active != true || c.error != null
          ? 'Refresh your wallet before adding a card.'
          : c.data?.capabilities['cardLinking'] != true
          ? 'Card setup is not enabled yet. Please try again later.'
          : null,
      onAdd: () async {
        if (!c.alive ||
            c.loading ||
            c.working ||
            c.error != null ||
            c.data?.active != true ||
            c.data?.capabilities['cardLinking'] != true) {
          return false;
        }
        await c.openOrLink('CARD');
        return c.alive &&
            c.error == null &&
            c.data?.methods.any(
                  (method) =>
                      method['type'] == 'CARD' &&
                      method['status'] == 'VERIFIED_MOCK',
                ) ==
                true;
      },
    ),
  );

  Future<void> _addMoney(CustomerWalletController c) async {
    if (c.data!.balance == null) {
      await c.openOrLink();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) =>
          AddMoneySheet(controller: c, onAddCard: () => _addCard(c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(customerWalletProvider);
    final profile = ref.watch(customerProfileControllerProvider);
    return Theme(
      data: CustomerTheme.light(),
      child: ListenableBuilder(
        listenable: Listenable.merge([c, profile]),
        builder: (context, _) => Scaffold(
          backgroundColor: CustomerColors.surface,
          bottomNavigationBar: const CustomerBottomNavigation(
            selected: CustomerNavigationTab.wallet,
          ),
          body: Column(
            children: [
              CustomerTopBar(
                photo: safeImageUrl(profile.profile?.details.profilePhoto),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: c.load,
                  child: SingleChildScrollView(
                    key: const ValueKey('customer-wallet-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (c.loading || c.working)
                              const LinearProgressIndicator(),
                            if (c.error != null)
                              _WalletMessage(
                                message: c.error!,
                                action: c.loading ? null : c.load,
                              ),
                            if (c.data == null && !c.loading && c.error == null)
                              const _WalletMessage(
                                message: 'Sign in to see your wallet.',
                              ),
                            if (c.data case final data?) ...[
                              if (!data.balanced)
                                const _WalletMessage(
                                  message: 'Your wallet needs a balance check. Please contact support before making payments.',
                                ),
                              if (data.balance != null &&
                                  data.balance!['status'] != 'ACTIVE')
                                const _WalletMessage(
                                  message: 'This wallet is currently inactive. Please contact support.',
                                ),
                              if (data.methods.any(
                                (m) => m['type'] == 'CARD',
                              )) ...[
                                const Text(
                                  'Wallet',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    color: CustomerColors.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Manage your money',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CustomerColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _balance(c, data),
                              const SizedBox(height: 14),
                              _heading(
                                'Payment methods',
                                'Manage',
                                () => _methods(c),
                              ),
                              const SizedBox(height: 6),
                              if (!data.methods.any(
                                (method) => method['type'] == 'CARD',
                              ))
                                _EmptyWalletPanel(
                                  icon: Icons.credit_card_rounded,
                                  title: 'No payment methods yet',
                                  message: 'Your saved payment methods will appear here.',
                                  action: OutlinedButton.icon(
                                    onPressed: c.working || c.loading
                                        ? null
                                        : () => _addCard(c),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add new payment method'),
                                  ),
                                )
                              else
                                for (final method
                                    in data.methods
                                        .where(
                                          (method) => method['type'] == 'CARD',
                                        )
                                        .take(2))
                                  _savedCard(method, c),
                              if (data.methods.any((m) => m['type'] == 'CARD'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      side: const BorderSide(
                                        color: CustomerColors.border,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: c.loading || c.working
                                        ? null
                                        : () => _addCard(c),
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 22,
                                    ),
                                    label: const Text('Add new payment method'),
                                  ),
                                ),
                              const SizedBox(height: 14),
                              KeyedSubtree(
                                key: _historyKey,
                                child: _heading(
                                  'Payment history',
                                  'View all',
                                  _history,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (c.entries.isEmpty)
                                const _EmptyWalletPanel(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No transactions yet',
                                  message: 'Your payments and wallet top-ups will appear here.',
                                ),
                              ..._transactions(c),
                              if (c.pageError != null)
                                _WalletMessage(
                                  message: c.pageError!,
                                  action: c.more,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedCard(
    Map<String, dynamic> method,
    CustomerWalletController c, {
    bool details = true,
  }) {
    final label = method['displayLabel'] as String;
    final brand = '${method['brand'] ?? ''}'.toLowerCase();
    final logo = {'visa', 'mastercard'}.contains(brand) ? brand : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: CustomerColors.border),
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF5FAFB)],
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        leading: Container(
          width: 44,
          height: 36,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CustomerColors.border),
          ),
          child: logo == null
              ? const Icon(
                  Icons.credit_card_rounded,
                  color: CustomerColors.action,
                )
              : SvgPicture.asset(
                  'assets/icons/payment/$logo.svg',
                  semanticsLabel: logo,
                ),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CustomerColors.text,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            method['status'] == 'VERIFIED_MOCK'
                ? 'Test payment method'
                : method['status'] as String,
            style: const TextStyle(
              fontSize: 12,
              color: CustomerColors.secondaryText,
            ),
          ),
        ),
        trailing: !details
            ? null
            : IconButton(
                tooltip: 'Payment method details',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _methods(c),
              ),
        onTap: details ? () => _methods(c) : null,
      ),
    );
  }

  Widget _heading(String title, String action, VoidCallback onTap) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CustomerColors.text,
          ),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ],
  );

  Widget _balance(CustomerWalletController c, WalletSnapshot data) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      children: [
        const Positioned.fill(child: CustomerHeaderBackground()),
        Container(
          key: const ValueKey('customer-wallet-balance'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.testFunds)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Test wallet · not real money',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  const Text(
                    'Available balance',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('customer-wallet-add-money'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed:
                        c.loading ||
                            c.working ||
                            c.error != null ||
                            !data.balanced ||
                            data.balance != null && !data.active
                        ? null
                        : () => _addMoney(c),
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: Text(
                      data.balance == null ? 'Open wallet' : 'Add money',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _hidden
                        ? '••••••'
                        : walletMoney(data.balance?['available'] ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('customer-wallet-visibility'),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.all(8),
                    visualDensity: VisualDensity.compact,
                    tooltip: _hidden ? 'Show balance' : 'Hide balance',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ],
              ),
              if (data.balance == null)
                const Text(
                  'Open your LKR wallet to get started.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: Colors.white30, height: 1),
              ),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final field in ['reserved', 'pending'])
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field == 'reserved' ? 'Reserved' : 'Pending',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _hidden
                              ? '••••'
                              : walletMoney(data.balance?[field] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _transactions(CustomerWalletController c, {bool all = false}) {
    final groups = <int, List<Map<String, dynamic>>>{};
    for (final entry in c.entries) {
      groups.putIfAbsent(entry['operationId'] as int, () => []).add(entry);
    }
    return groups.values.take(all ? groups.length : 3).map((rows) {
      final row = rows.first;
      final type = row['type'] as String?;
      final title = switch (type) {
        'TOPUP' => 'Wallet top-up',
        'BOOKING_RESERVE' => 'Booking reservation',
        'WALLET_BOOKING_SETTLE' => 'Booking payment',
        'WITHDRAWAL' => 'Withdrawal',
        _ => 'Wallet activity',
      };
      final createdAt = DateTime.parse(row['createdAt'] as String).toLocal();
      final date =
          '${MaterialLocalizations.of(context).formatShortDate(createdAt)} ${TimeOfDay.fromDateTime(createdAt).format(context)}';
      final available = rows.where((r) => r['bucket'] == 'AVAILABLE').toList();
      final amount = available.isEmpty
          ? null
          : available.fold<BigInt>(
              BigInt.zero,
              (total, r) => total + walletMinorUnits(r['delta']),
            );
      String? formatted;
      if (amount != null) {
        final digits = amount.abs().toString().padLeft(3, '0');
        formatted = walletMoney(
          '${amount.isNegative ? '-' : ''}${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}',
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
          horizontalTitleGap: 8,
          minLeadingWidth: 28,
          minVerticalPadding: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: CustomerColors.border),
          ),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE4F8F8),
            child: Icon(
              type == 'TOPUP'
                  ? Icons.arrow_upward_rounded
                  : Icons.receipt_long_outlined,
              color: CustomerColors.action,
              size: 16,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$date${['MOCK', 'PAYHERE_SANDBOX'].contains(row['fundingMode']) ? ' · Test transaction' : ''}',
            style: const TextStyle(fontSize: 10, height: 1.2),
          ),
          trailing: formatted == null
              ? null
              : Text(
                  _hidden ? '••••' : formatted,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: amount != null && amount > BigInt.zero
                        ? const Color(0xFF258048)
                        : CustomerColors.text,
                  ),
                ),
        ),
      );
    }).toList();
  }
}

class _WalletMessage extends StatelessWidget {
  const _WalletMessage({required this.message, this.action});
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: CustomerColors.secondaryText),
        ),
        if (action != null)
          TextButton(onPressed: action, child: const Text('Retry')),
      ],
    ),
  );
}

class _EmptyWalletPanel extends StatelessWidget {
  const _EmptyWalletPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPanelBorder(),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: CustomerColors.selection,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: CustomerColors.action, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: CustomerColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: CustomerColors.secondaryText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    ),
  );
}

class _DashedPanelBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );
    final paint = Paint()
      ..color = const Color(0xFFD7DEE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 9) {
        canvas.drawPath(metric.extractPath(start, start + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
