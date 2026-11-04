import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import 'booking_payment_visuals.dart';

/// Read-only pending state. Only backend refresh can confirm its outcome.
class BookingPaymentPending extends StatefulWidget {
  const BookingPaymentPending({
    super.key,
    required this.requestId,
    required this.amount,
    required this.method,
    required this.busy,
    required this.onRefresh,
    this.autoRefresh = true,
  });
  final Object? requestId;
  final String? amount;
  final String method;
  final bool busy;
  final VoidCallback onRefresh;
  final bool autoRefresh;

  @override
  State<BookingPaymentPending> createState() => _BookingPaymentPendingState();

  Widget _buildContents(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentArtHeading(
            title: 'Checking your payment',
            requestId: requestId,
          ),
          const SizedBox(height: 22),
          if (amount != null) ...[
            PaymentAmountArtwork(
              amount: amount!,
              label: 'Payment amount',
              banner: false,
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Payment method',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: paymentInk,
            ),
          ),
          const SizedBox(height: 10),
          PaymentSelectedMethod(method: method, showRadio: false),
          const SizedBox(height: 18),
          const PaymentStatusNotice(
            title: 'Waiting for payment confirmation',
            message: 'We are checking your payment automatically. Please wait for confirmation before trying to pay again.',
            pending: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'You do not need to make another payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: CustomerColors.secondaryText),
          ),
        ],
      ),
    ),
  );
}

class _BookingPaymentPendingState extends State<BookingPaymentPending>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    if (widget.autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    }
  }

  void _refresh() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        !widget.autoRefresh ||
        widget.busy ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    widget.onRefresh();
  }

  @override
  void didUpdateWidget(covariant BookingPaymentPending oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRefresh != widget.autoRefresh ||
        oldWidget.requestId != widget.requestId) {
      _startPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._buildContents(context);
}
