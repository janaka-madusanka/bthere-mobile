part of 'wallet_screen.dart';

Text _walletText(
  String label,
  double size, {
  bool bold = false,
  Color color = _walletInk,
}) => Text(
  label,
  style: TextStyle(
    fontFamily: 'HomeLato',
    fontSize: size,
    height: 1.25,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    color: color,
  ),
);

BoxDecoration _panelDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(11),
  border: Border.all(color: const Color(0xFFE9EFF7)),
);

class _WalletMessage extends StatelessWidget {
  const _WalletMessage({required this.text, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Semantics(
      liveRegion: true,
      child: _walletText(
        text,
        11,
        color: error ? const Color(0xFFB53D52) : _walletTeal,
      ),
    ),
  );
}

class _BalanceCard extends StatefulWidget {
  const _BalanceCard({
    required this.balance,
    required this.scale,
    this.compact = false,
    this.onTopup,
  });
  final WalletBalance balance;
  final double scale;
  final bool compact;
  final VoidCallback? onTopup;
  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hidden = false;
  String money(WalletMoney amount) =>
      _hidden ? '••••••' : 'LKR ${amount.formatted}';
  @override
  Widget build(BuildContext context) {
    final s = widget.scale, balance = widget.balance;
    if (widget.compact) {
      return Container(
        key: const ValueKey('wallet-balance'),
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 15 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xff00747a), Color(0xff00b9b8)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _walletText(
                          'Available Balance',
                          12 * s,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: _hidden ? 'Show balance' : 'Hide balance',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 15 * s,
                          color: const Color(0xffb7f8ec),
                        ),
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _walletText(
                      money(balance.available),
                      27 * s,
                      bold: true,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onTopup,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _walletInk,
                        disabledBackgroundColor: const Color(0xffd9eeee),
                        disabledForegroundColor: const Color(0xff607e88),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * s,
                          vertical: 10 * s,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(
                        Icons.add_circle,
                        color: widget.onTopup == null
                            ? null
                            : const Color(0xff008d95),
                        size: 16 * s,
                      ),
                      label: Text(
                        'Top Up Wallet',
                        style: TextStyle(
                          fontSize: 12 * s,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * s),
            Expanded(
              flex: 4,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 120 * s,
                  child: CustomPaint(painter: _WalletBannerArt()),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      key: const ValueKey('wallet-balance'),
      padding: EdgeInsets.all(13 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF009399), Color(0xFF00747A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 22 * s,
                        ),
                        SizedBox(width: 8 * s),
                        Flexible(
                          child: _walletText(
                            'Available Balance',
                            12 * s,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4 * s),
                        SizedBox(
                          width: 28 * s,
                          height: 28 * s,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: _hidden ? 'Show balance' : 'Hide balance',
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 15 * s,
                              color: const Color(0xFF70E3DC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _walletText(
                      money(balance.available),
                      24 * s,
                      bold: true,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    _walletText(
                      'Available wallet balance',
                      11 * s,
                      color: const Color(0xFFD2F5F1),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * s),
              // The supplied Figma node is flattened; this native illustration keeps
              // the balance and controls interactive without embedding a screenshot.
              Expanded(
                flex: 3,
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 85 * s,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96 * s,
                          height: 70 * s,
                          decoration: BoxDecoration(
                            color: const Color(0xFF12B8B0),
                            borderRadius: BorderRadius.circular(35),
                          ),
                        ),
                        Transform.rotate(
                          angle: -.14,
                          child: Icon(
                            Icons.payments_outlined,
                            size: 75 * s,
                            color: const Color(0xFF77E9D8),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 72 * s,
                            color: const Color(0xFFDCFFF3),
                          ),
                        ),
                        Positioned(
                          right: 5,
                          top: 0,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 22 * s,
                            color: const Color(0xFF67E0D6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * s),
          Container(
            padding: EdgeInsets.all(10 * s),
            decoration: BoxDecoration(
              color: const Color(0x30FFFFFF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _walletText(
                        money(balance.available),
                        12 * s,
                        bold: true,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 3),
                      _walletText(
                        'Available to withdraw',
                        10 * s,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _walletText(
                        money(balance.pending),
                        12 * s,
                        bold: true,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 3),
                      _walletText(
                        'Pending (in progress)',
                        10 * s,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (balance.reserved.minor > BigInt.zero)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _walletText(
                '${money(balance.reserved)} reserved',
                10 * s,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletBannerArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 125);
    final paint = Paint();
    canvas.drawOval(
      const Rect.fromLTWH(0, 10, 120, 112),
      paint..color = const Color(0x3029fff0),
    );
    canvas.save();
    canvas.translate(12, 35);
    canvas.rotate(.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 96, 76),
        const Radius.circular(13),
      ),
      paint..color = const Color(0xff00646c),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 6, 86, 64),
        const Radius.circular(10),
      ),
      paint..color = const Color(0xff009799),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, -2, 76, 9),
        const Radius.circular(5),
      ),
      paint..color = const Color(0xffa3f9df),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 7, 83, 64),
        const Radius.circular(9),
      ),
      paint..color = const Color(0xff00858b),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 25, 35, 27),
        const Radius.circular(7),
      ),
      paint..color = const Color(0xff005f69),
    );
    canvas.drawCircle(
      const Offset(79, 38),
      4,
      paint..color = const Color(0xff7de3d2),
    );
    for (final offset in [
      const Offset(36, 30),
      const Offset(43, 36),
      const Offset(37, 43),
      const Offset(30, 36),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: offset, width: 6, height: 10),
        paint..color = const Color(0xffb4ffec),
      );
    }
    canvas.restore();
    for (final coin in [const Offset(43, 13), const Offset(94, 28)]) {
      canvas.drawCircle(coin, 11, paint..color = const Color(0xffffc45a));
      canvas.drawCircle(coin, 8, paint..color = const Color(0xffffa637));
      final text = TextPainter(
        text: const TextSpan(
          text: '+',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, coin - Offset(text.width / 2, text.height / 2));
    }
    for (final spark in [
      const Offset(83, 7),
      const Offset(112, 48),
      const Offset(12, 28),
    ]) {
      canvas.drawCircle(spark, 2, paint..color = const Color(0xffa6fff0));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalletBannerArt oldDelegate) => false;
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.scale,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double scale;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFECFAFA),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 9 * scale,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18 * scale,
              backgroundColor: const Color(0xFFC9F6F1),
              child: Icon(
                icon,
                color: onTap == null ? _walletMuted : const Color(0xFF00797E),
                size: 23 * scale,
              ),
            ),
            SizedBox(width: 9 * scale),
            Expanded(
              child: _walletText(
                label,
                11 * scale,
                bold: true,
                color: onTap == null ? _walletMuted : _walletInk,
              ),
            ),
            Icon(Icons.chevron_right, size: 17 * scale, color: _walletMuted),
          ],
        ),
      ),
    ),
  );
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({
    required this.snapshot,
    required this.scale,
    this.onManage,
  });
  final WalletSnapshot snapshot;
  final double scale;
  final VoidCallback? onManage;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(10 * scale),
    decoration: _panelDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20 * scale,
              backgroundColor: const Color(0xFFE0FAF6),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: _walletTeal,
                size: 23 * scale,
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _walletText(
                    'My Payment & Withdrawal Methods',
                    13 * scale,
                    bold: true,
                  ),
                  const SizedBox(height: 3),
                  _walletText(
                    'These methods are used for wallet top-ups and withdrawals.',
                    10 * scale,
                    color: _walletMuted,
                  ),
                ],
              ),
            ),
            if (onManage != null)
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 6),
                  minimumSize: const Size(42, 32),
                ),
                child: _walletText('Manage ›', 10 * scale, color: _walletTeal),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (snapshot.methods.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No payment methods added yet.'),
          ),
        for (final method in snapshot.methods)
          _MethodRow(method: method, scale: scale),
        if (onManage != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD7E2EF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: Size(0, 33 * scale),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(
                Icons.add_circle_outline,
                size: 18 * scale,
                color: _walletTeal,
              ),
              label: _walletText(
                'Add New Payment Method',
                10 * scale,
                color: _walletTeal,
              ),
            ),
          ),
      ],
    ),
  );
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.scale});
  final WalletMethod method;
  final double scale;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: EdgeInsets.all(7 * scale),
    decoration: _panelDecoration(),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16 * scale,
          backgroundColor: method.card
              ? const Color(0xFFEAF7FF)
              : const Color(0xFFE0FAF6),
          child: Icon(
            method.card ? Icons.credit_card : Icons.account_balance_outlined,
            color: method.card ? const Color(0xFF00A7FF) : _walletTeal,
            size: 20 * scale,
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _walletText(method.label, 10.5 * scale, bold: true),
              const SizedBox(height: 3),
              _walletText(
                method.usable ? 'Ready to use' : method.status,
                9 * scale,
                color: _walletMuted,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0FAF6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _walletText(
              method.card ? 'Card top-ups' : 'Withdrawals',
              8.5 * scale,
              color: _walletTeal,
            ),
          ),
        ),
      ],
    ),
  );
}

List<List<WalletEntry>> _groupEntries(List<WalletEntry> entries) {
  final groups = <int, List<WalletEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.operationId, () => []).add(entry);
  }
  return groups.values.toList();
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.entries, required this.scale});
  final List<WalletEntry> entries;
  final double scale;
  @override
  Widget build(BuildContext context) {
    // An operation can move between buckets. Never sum it into a new charge.
    final entry =
        entries.where((e) => e.bucket == 'AVAILABLE').firstOrNull ??
        entries.first;
    final negative = entry.delta.minor.isNegative;
    final date = entry.createdAt;
    final stamp =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _walletText(
                    'Wallet operation #${entry.operationId}',
                    18,
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  for (final row in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${row.bucket}: ${row.delta.decimal} LKR\nBalance ${row.before.formatted} → ${row.after.formatted}\nEntry #${row.id} · $stamp',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(10 * scale),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18 * scale,
              backgroundColor: negative
                  ? const Color(0xFFFFE9EC)
                  : const Color(0xFFE0FAF6),
              child: Icon(
                negative
                    ? Icons.remove_circle_outline
                    : Icons.account_balance_wallet,
                size: 19 * scale,
                color: negative ? const Color(0xFFFF5366) : _walletTeal,
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _walletText(
                    entries.length > 1
                        ? 'Wallet transfer'
                        : negative
                        ? 'Wallet debit'
                        : 'Wallet credit',
                    11 * scale,
                    bold: true,
                  ),
                  const SizedBox(height: 3),
                  _walletText(
                    'Operation #${entry.operationId} · ${entry.bucket.toLowerCase()}',
                    10 * scale,
                    color: _walletMuted,
                  ),
                  _walletText(stamp, 9 * scale, color: const Color(0xFFA4B4CF)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _walletText(
                    '${negative ? '-' : '+'} LKR ${WalletMoney(entry.delta.minor.abs()).formatted}',
                    12 * scale,
                    bold: true,
                    color: negative ? _walletMuted : _walletTeal,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0FAF6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _walletText('Posted', 9 * scale, color: _walletTeal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPayment extends ConsumerWidget {
  const _PendingPayment({required this.value});
  final WalletViewState value;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(walletControllerProvider.notifier);
    final request = value.request!;
    final caps = value.snapshot.capabilities;
    final permitted = request.purpose == 'TOPUP'
        ? caps.topups && caps.cardLinking
        : caps.withdrawals;
    final canConfirm =
        permitted &&
        value.intent?.status == 'PENDING' &&
        (request.methodId == null
            ? request.purpose == 'TOPUP'
            : value.snapshot.methods.any(
                (m) => m.id == request.methodId && m.usable,
              ));
    return Card(
      color: const Color(0xFFF0FBFA),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _walletText('Payment needs confirmation', 14, bold: true),
            const SizedBox(height: 4),
            Text(
              '${request.purpose == 'TOPUP' ? 'Top-up' : 'Withdrawal'} · LKR ${request.amount.formatted}',
            ),
            const Text(
              'Do not submit another payment while this request is unresolved.',
              style: TextStyle(fontSize: 11),
            ),
            TextButton(
              onPressed: value.busy ? null : controller.checkPayment,
              child: Text(
                request.intentId == null
                    ? 'Retry safely'
                    : 'Check payment status',
              ),
            ),
            if (canConfirm && value.snapshot.canMove) ...[
              const Text(
                'Choose a result to complete this payment.',
                style: TextStyle(fontSize: 11),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: value.busy
                        ? null
                        : () => controller.simulate('SUCCESS'),
                    child: const Text('Confirm payment'),
                  ),
                  TextButton(
                    onPressed: value.busy
                        ? null
                        : () => controller.simulate('FAILURE'),
                    child: const Text('Decline payment'),
                  ),
                  TextButton(
                    onPressed: value.busy
                        ? null
                        : () => controller.simulate('PENDING'),
                    child: const Text('Keep pending'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
