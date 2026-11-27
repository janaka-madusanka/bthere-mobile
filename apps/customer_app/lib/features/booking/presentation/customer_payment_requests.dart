import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../../app/customer_providers.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../application/customer_request_recovery.dart';

/// Compact payment recovery shared by Home Recent, Booking and job details.
class CustomerPaymentRequests extends ConsumerStatefulWidget {
  const CustomerPaymentRequests({
    super.key,
    this.jobId,
    this.requestId,
    this.awaitingPayment = false,
    this.detailsStyle = false,
    this.compact = false,
  });
  final int? jobId;
  final int? requestId;
  final bool awaitingPayment;
  final bool detailsStyle;
  final bool compact;
  @override
  ConsumerState<CustomerPaymentRequests> createState() =>
      _CustomerPaymentRequestsState();
}

class _CustomerPaymentRequestsState
    extends ConsumerState<CustomerPaymentRequests>
    with WidgetsBindingObserver {
  Timer? timer;
  Timer? countdown;
  void _refresh() {
    if (!mounted) return;
    final recovery = ref.read(customerRequestRecoveryProvider);
    if (widget.jobId != null) {
      if (!widget.awaitingPayment) return;
      recovery.refreshJob(widget.jobId!, requestId: widget.requestId);
    } else {
      recovery.refresh();
    }
  }

  bool get foreground =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) return;
      final recovery = ref.read(customerRequestRecoveryProvider);
      if (widget.requestId != null && widget.requestId! > 0) {
        try {
          await recovery.remember(widget.requestId!);
        } catch (_) {}
      }
      _refresh();
    });
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!foreground) return;
      _refresh();
    });
    countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (foreground) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    countdown?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recovery = ref.watch(customerRequestRecoveryProvider);
    return ListenableBuilder(
      listenable: recovery,
      builder: (context, _) {
        final rows = recovery.active
            .where((r) => widget.jobId == null || r['jobId'] == widget.jobId)
            .toList();
        if (widget.compact) {
          rows.removeWhere((r) {
            final expires = DateTime.tryParse('${r['confirmationExpiresAt']}');
            return r['status'] == 'AWAITING_CUSTOMER_CONFIRMATION' &&
                expires != null &&
                !expires.isAfter(ref.read(customerClockProvider)());
          });
          if (rows.isEmpty) return const SizedBox.shrink();
          return _ActiveRequestCard(rows: rows);
        }
        if (rows.isEmpty && recovery.error == null) {
          final resolved = recovery.requests.values.any(
            (row) => row['jobId'] == widget.jobId,
          );
          if (widget.awaitingPayment && !resolved) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  tileColor: CustomerColors.selection,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: const Text(
                    'Checking payment status',
                    style: CustomerTypography.card,
                  ),
                  subtitle: const Text(
                    'Loading your payment deadline and available actions.',
                    style: CustomerTypography.compact,
                  ),
                  onTap: _refresh,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recovery.error != null)
              TextButton(onPressed: _refresh, child: Text(recovery.error!)),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestTile(
                  row: row,
                  detailsStyle: widget.detailsStyle,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActiveRequestCard extends ConsumerWidget {
  const _ActiveRequestCard({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = rows.first;
    final matching = row['status'] == 'MATCHING';
    final checking = {
      'PAYMENT_PENDING',
      'PAYMENT_RECONCILIATION',
    }.contains(row['status']);
    final failed =
        row['paymentStatus'] == 'FAILED' ||
        row['paymentRetryStartedAt'] != null;
    final expiry = DateTime.tryParse('${row['confirmationExpiresAt']}');
    final seconds = expiry
        ?.difference(ref.read(customerClockProvider)())
        .inSeconds;
    final urgent = seconds != null && seconds <= 30;
    void open(int id) => context.push('/booking-requests/$id/payment');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        key: const ValueKey('active-request-mini-card'),
        color: urgent && !matching
            ? const Color(0xFFFFF1DA)
            : const Color(0xFFE2F5F3),
        elevation: 3,
        shadowColor: const Color(0x180B3037),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: matching
              ? ValueKey('active-matching-request-${row['requestId']}')
              : null,
          borderRadius: BorderRadius.circular(18),
          onTap: () => open(row['requestId'] as int),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  matching
                      ? Icons.person_search_outlined
                      : checking
                      ? Icons.schedule
                      : Icons.payments_outlined,
                  color: CustomerColors.action,
                  size: 25,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        matching
                            ? 'Finding your provider…'
                            : checking
                            ? 'Checking payment'
                            : failed
                            ? 'Payment failed'
                            : 'Provider accepted · Confirm payment',
                        style: CustomerTypography.compactStrong,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Request #${row['requestId']}'
                        '${!matching && !checking && seconds != null ? ' · ${seconds.clamp(0, 2147483647) ~/ 60}:${(seconds.clamp(0, 2147483647) % 60).toString().padLeft(2, '0')} remaining' : ' · Tap to continue'}',
                        style: CustomerTypography.compact,
                      ),
                    ],
                  ),
                ),
                if (rows.length > 1)
                  PopupMenuButton<int>(
                    tooltip: 'Other active requests',
                    onSelected: open,
                    itemBuilder: (_) => [
                      for (final item in rows)
                        PopupMenuItem(
                          value: item['requestId'] as int,
                          child: Text(
                            'Request #${item['requestId']} · ${item['status'] == 'MATCHING' ? 'Finding provider' : 'Payment'}',
                          ),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('+${rows.length - 1}'),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: CustomerColors.action),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.row, this.detailsStyle = false});
  final Map<String, dynamic> row;
  final bool detailsStyle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (row['status'] == 'MATCHING') {
      return Material(
        color: CustomerColors.selection,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          key: ValueKey('active-matching-request-${row['requestId']}'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(
            Icons.person_search_outlined,
            color: CustomerColors.action,
          ),
          title: const Text(
            'Finding a provider',
            style: CustomerTypography.card,
          ),
          subtitle: Text(
            'Request #${row['requestId']} \u00b7 Tap to continue',
            style: CustomerTypography.compact,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: CustomerColors.action,
          ),
          onTap: () =>
              context.push('/booking-requests/${row['requestId']}/payment'),
        ),
      );
    }
    final pending = {
      'PAYMENT_PENDING',
      'PAYMENT_RECONCILIATION',
    }.contains(row['status']);
    final failed =
        row['paymentStatus'] == 'FAILED' ||
        DateTime.tryParse('${row['paymentRetryStartedAt']}') != null;
    final expiry = DateTime.tryParse('${row['confirmationExpiresAt']}');
    final seconds = expiry
        ?.difference(ref.read(customerClockProvider)())
        .inSeconds;
    final expired = seconds != null && seconds <= 0;
    final urgent = seconds != null && seconds > 0 && seconds <= 30;
    final title = pending
        ? 'Checking payment'
        : expired
        ? 'Payment time ended'
        : failed
        ? 'Payment failed'
        : 'Payment required';
    final time = seconds == null
        ? 'Open to check payment deadline'
        : '${seconds.clamp(0, 2147483647) ~/ 60}m ${seconds.clamp(0, 2147483647) % 60}s remaining';
    final action = pending || expired || row['canPay'] != true
        ? 'View status'
        : failed
        ? 'Retry payment'
        : 'Pay now';
    if (detailsStyle) {
      final button = FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: CustomerColors.action,
          textStyle: CustomerTypography.compactStrong.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: () =>
            context.push('/booking-requests/${row['requestId']}/payment'),
        icon: Icon(
          pending ? Icons.schedule_rounded : Icons.refresh_rounded,
          size: 16,
        ),
        label: Text(action),
      );
      final description = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/navigation/wallet.svg',
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                if (failed && !pending)
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF04452),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: .3),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? 'Checking payment'
                      : expired
                      ? 'Payment time ended'
                      : failed
                      ? 'Retry Payment'
                      : 'Complete your payment',
                  style: CustomerTypography.card.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pending
                      ? 'Waiting for the verified payment result.'
                      : expired
                      ? 'Open to check the latest booking status.'
                      : failed
                      ? 'The payment for this booking has failed. Please try again.'
                      : 'Confirm payment to secure your booking.',
                  style: CustomerTypography.compact.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('booking-payment-retry-banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00AAA9),
                  Color(0xFF00777D),
                  Color(0xFF009E9B),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: const _RetryBannerWaves(),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  if (bounds.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(12) > 16) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        description,
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: button),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: description),
                      const SizedBox(width: 10),
                      button,
                    ],
                  );
                },
              ),
            ),
          ),
          if (!pending)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                time,
                textAlign: TextAlign.end,
                style: CustomerTypography.compactStrong.copyWith(
                  color: urgent
                      ? CustomerColors.warning
                      : CustomerColors.secondaryText,
                ),
              ),
            ),
        ],
      );
    }
    return Material(
      color: urgent ? const Color(0xFFFFF4DE) : CustomerColors.selection,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CustomerColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/booking-requests/${row['requestId']}/payment'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                pending ? Icons.schedule : Icons.payments_outlined,
                color: urgent ? CustomerColors.warning : CustomerColors.action,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CustomerTypography.card),
                    Text(
                      'Request #${row['requestId']}${row['jobId'] == null ? '' : ' · Booking #${row['jobId']}'}',
                      style: CustomerTypography.compact,
                    ),
                    Text(
                      pending
                          ? 'Waiting for the verified payment result'
                          : time,
                      style: CustomerTypography.compact,
                    ),
                    if (row['expectedAmount'] != null)
                      Text(
                        row['currencyCode'] == 'LKR'
                            ? walletMoney(row['expectedAmount'])
                            : '${row['currencyCode']} ${row['expectedAmount']}',
                        style: CustomerTypography.card,
                      ),
                    Text(
                      action,
                      style: CustomerTypography.compactStrong.copyWith(
                        color: CustomerColors.action,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CustomerColors.action),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryBannerWaves extends CustomPainter {
  const _RetryBannerWaves();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .055);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .1,
        -size.height * .7,
        size.width * .35,
        size.height * 1.1,
      ),
      paint,
    );
    final wave = Path()
      ..moveTo(size.width * .34, 0)
      ..cubicTo(
        size.width * .3,
        size.height * .5,
        size.width * .7,
        size.height * .6,
        size.width * .55,
        size.height,
      )
      ..lineTo(size.width * .7, size.height)
      ..cubicTo(
        size.width * .85,
        size.height * .5,
        size.width * .47,
        size.height * .5,
        size.width * .5,
        0,
      )
      ..close();
    canvas.drawPath(wave, paint);
  }

  @override
  bool shouldRepaint(covariant _RetryBannerWaves oldDelegate) => false;
}
