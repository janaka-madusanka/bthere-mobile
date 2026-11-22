import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bthere_network/bthere_network.dart';

import '../../../app/providers/app_providers.dart';
import '../application/booking_controller.dart';
import '../data/booking_repository.dart';
import '../domain/booking_models.dart';
import 'booking_scaffold.dart';

class BookingPaymentWindowCard extends ConsumerStatefulWidget {
  const BookingPaymentWindowCard({
    super.key,
    required this.requestId,
    this.serviceStart,
  });
  final int requestId;
  final String? serviceStart;
  @override
  ConsumerState<BookingPaymentWindowCard> createState() =>
      _PaymentWindowState();
}

class _PaymentWindowState extends ConsumerState<BookingPaymentWindowCard> {
  BookingPaymentWindow? window;
  String? error;
  bool loading = false;
  bool acting = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (loading || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref
          .read(bookingRepositoryProvider)
          .paymentWindow(widget.requestId);
      if (mounted) setState(() => window = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          window = null;
          error = e is NetworkException
              ? e.message
              : 'Unable to check the payment window.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _act({required bool cancel}) async {
    if (acting) return;
    setState(() => acting = true);
    try {
      await _performAction(cancel: cancel);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> _performAction({required bool cancel}) async {
    // Recheck the lifecycle before presenting a mutation.
    await _load();
    if (!mounted || window == null || loading) return;
    final current = window!;
    final now = ref.read(clockProvider)().toUtc();
    if (!current.deadline.isAfter(now) ||
        (cancel ? !current.canCancel : !current.canExtend)) {
      return;
    }
    DateTime? target;
    if (!cancel) {
      final start = DateTime.tryParse(widget.serviceStart ?? '')?.toUtc();
      var maxTarget = current.limit;
      if (start != null && !maxTarget.isBefore(start)) {
        maxTarget = start.subtract(const Duration(seconds: 1));
      }
      final candidates = [
        for (final minutes in [5, 10, 15])
          current.deadline.add(Duration(minutes: minutes)),
      ].where((date) => !date.isAfter(maxTarget)).toSet();
      if (maxTarget.isAfter(current.deadline)) candidates.add(maxTarget);
      if (candidates.isEmpty) return;
      target = await showDialog<DateTime>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Extend payment deadline'),
          children: [
            for (final date in candidates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, date),
                child: Text('Until ${date.toLocal()}'),
              ),
          ],
        ),
      );
      if (target == null || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel unpaid booking?'),
          content: const Text(
            'This releases your reserved capacity and notifies the customer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel booking'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final controller = ref.read(bookingControllerProvider.notifier);
    if (cancel) {
      await controller.cancelUnpaid(widget.requestId);
    } else {
      await controller.extendDeadline(widget.requestId, target!);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        acting ||
        loading ||
        (ref.watch(bookingControllerProvider).asData?.value.busy ?? false);
    final current = window;
    final active =
        current != null && current.deadline.isAfter(ref.read(clockProvider)());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Customer payment window',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: bookingInk,
            ),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (current != null) ...[
            Text('Payment deadline: ${current.deadline.toLocal()}'),
            const SizedBox(height: 8),
            Text(
              [
                        'PAYMENT_PENDING',
                        'PAYMENT_RECONCILIATION',
                      ].contains(current.status) ||
                      [
                        'PENDING',
                        'PAYMENT_PENDING',
                        'PAYMENT_RECONCILIATION',
                      ].contains(current.paymentStatus)
                  ? 'Payment is being verified. Keep this booking reserved while reconciliation finishes.'
                  : !active
                  ? 'The payment window has ended. Refresh booking details for the latest status.'
                  : 'Waiting for customer payment. Your capacity remains reserved.',
              style: const TextStyle(color: bookingMuted, height: 1.5),
            ),
            if (current.canExtend && active)
              OutlinedButton.icon(
                onPressed: busy ? null : () => _act(cancel: false),
                icon: const Icon(Icons.more_time),
                label: const Text('Extend deadline'),
              ),
            if (current.canCancel && active)
              TextButton(
                onPressed: busy ? null : () => _act(cancel: true),
                child: const Text('Cancel unpaid booking'),
              ),
          ],
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await _load();
                    await ref
                        .read(bookingControllerProvider.notifier)
                        .refresh();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh payment status'),
          ),
        ],
      ),
    );
  }
}
