import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/booking_models.dart' show MarketTime;

import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../../../app/customer_providers.dart';
import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_booking_history.dart';
import '../domain/booking_auto_cancel.dart';

/// Only the server cancels/refunds. Local time changes presentation, never status.
class CustomerBookingAutoCancel extends ConsumerStatefulWidget {
  const CustomerBookingAutoCancel({
    super.key,
    required this.booking,
    this.onChanged,
  });
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  @override
  ConsumerState<CustomerBookingAutoCancel> createState() => _AutoCancelState();
}

class _AutoCancelState extends ConsumerState<CustomerBookingAutoCancel>
    with WidgetsBindingObserver {
  Timer? ticker;
  int seconds = 0;
  bool reading = false;
  String? error;
  int? owner;
  bool get foreground =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  bool get alive =>
      mounted &&
      owner != null &&
      ref.read(customerAuthControllerProvider).user?.id == owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;
  bool get waiting =>
      widget.booking['status'] == 'CONFIRMED' &&
      widget.booking['actualStartedAt'] == null &&
      autoCancelInstant(widget.booking['autoCancelAt']) != null;
  @override
  void initState() {
    super.initState();
    owner = widget.onChanged == null
        ? null
        : ref.read(customerAuthControllerProvider).user?.id;
    WidgetsBinding.instance.addObserver(this);
    sync();
  }

  void sync() {
    ticker?.cancel();
    if (!waiting) return;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!foreground || !alive) return;
      setState(() {});
      if (++seconds % 15 == 0) unawaited(reload());
    });
  }

  @override
  void didUpdateWidget(CustomerBookingAutoCancel old) {
    super.didUpdateWidget(old);
    if (old.booking['jobId'] != widget.booking['jobId'] ||
        old.booking['autoCancelAt'] != widget.booking['autoCancelAt'] ||
        old.booking['status'] != widget.booking['status']) {
      sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sync();
      if (foreground && waiting) unawaited(reload());
    } else {
      ticker?.cancel();
    }
  }

  Future<void> reload() async {
    if (reading || !alive || !foreground || widget.onChanged == null) return;
    reading = true;
    final id = widget.booking['jobId'];
    final previousStatus = widget.booking['status'];
    try {
      final rows = await ref.read(customerBookingRepositoryProvider).history();
      if (!alive || widget.booking['jobId'] != id) return;
      final latest = rows.where((row) => row['jobId'] == id).firstOrNull;
      if (latest == null) throw const FormatException('Booking unavailable');
      error = null;
      widget.onChanged!(latest);
      if (latest['status'] != previousStatus) {
        ref.invalidate(customerBookingHistoryProvider(owner!));
        if (latest['status'] == 'CANCELLED') {
          ref.invalidate(customerWalletProvider);
        }
      }
    } catch (_) {
      if (alive) setState(() => error = 'Could not refresh booking status.');
    } finally {
      reading = false;
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Plain details and older bookings do not need a clock or network scope.
    if (autoCancelInstant(widget.booking['autoCancelAt']) == null &&
        !(widget.booking['status'] == 'CANCELLED' &&
            widget.booking['cancellation'] is Map &&
            (widget.booking['cancellation'] as Map)['automatic'] == true)) {
      return const SizedBox.shrink();
    }
    final now = ref.read(customerClockProvider)().toUtc();
    final state = bookingAutoCancelState(widget.booking, now);
    if (state == AutoCancelState.none) return const SizedBox.shrink();
    if (state == AutoCancelState.autoCancelled) {
      final cancellation = widget.booking['cancellation'] as Map;
      final refund = cancellation['refundAmount'];
      final currency = cancellation['currencyCode'];
      return Container(
        key: const ValueKey('booking-auto-cancelled'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFF1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking cancelled automatically',
              style: CustomerTypography.compactStrong,
            ),
            const SizedBox(height: 6),
            Text(
              cancellation['reason'] == 'NOT_STARTED_IN_SERVICE_WINDOW'
                  ? 'The service was not started before its service window closed.'
                  : 'Your provider did not start the service in time.',
              style: CustomerTypography.compact,
            ),
            if (widget.booking['paymentStatus'] == 'REFUNDED' &&
                refund is num &&
                refund.isFinite &&
                refund >= 0 &&
                currency is String)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$currency ${walletMoney(refund).replaceFirst('Rs. ', '')} refunded to your wallet.',
                  style: CustomerTypography.compactStrong,
                ),
              ),
            TextButton(
              onPressed: () => context.go('/services'),
              child: const Text('Book again'),
            ),
          ],
        ),
      );
    }
    final deadline = autoCancelInstant(widget.booking['autoCancelAt'])!;
    final left = deadline.difference(now).inSeconds.clamp(0, 999999999);
    String two(int n) => n.toString().padLeft(2, '0');
    final countdown =
        '${two(left ~/ 3600)}:${two(left ~/ 60 % 60)}:${two(left % 60)}';
    String? deadlineLabel;
    final zone = widget.booking['marketTimezone'];
    if (zone is String) {
      try {
        final local = tz.TZDateTime.from(deadline, MarketTime.location(zone));
        final l = MaterialLocalizations.of(context);
        deadlineLabel =
            '${l.formatShortMonthDay(local)} - ${l.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
      } catch (_) {
        /* The countdown remains valid without a display timezone. */
      }
    }
    final overdueLong = now.difference(deadline) >= const Duration(minutes: 15);
    final title = switch (state) {
      AutoCancelState.heldArrived => 'Your provider has arrived',
      AutoCancelState.heldCodeTried => 'Check your start code',
      AutoCancelState.overdue =>
        overdueLong ? 'Cancellation is taking longer' : 'Cancelling...',
      _ => 'Service has not started',
    };
    final message = switch (state) {
      AutoCancelState.heldArrived => 'Share your start code. The booking is held while your provider is at the location.',
      AutoCancelState.heldCodeTried =>
        'Your provider is trying to start. Check the code you shared.',
      AutoCancelState.overdue =>
        overdueLong
            ? 'Cancellation and refund are not confirmed yet. Admin review may be needed.'
            : 'We are checking the server for cancellation and your wallet refund.',
      _ => 'If your provider does not start before this countdown ends, the server will cancel the booking with a full wallet refund. Cancelling it yourself may use the normal refund policy.',
    };
    return Container(
      key: const ValueKey('booking-auto-cancel'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CustomerTypography.compactStrong),
          const SizedBox(height: 6),
          Text(message, style: CustomerTypography.compact),
          if (deadlineLabel != null && state == AutoCancelState.cancelsSoon)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Automatic cancellation: $deadlineLabel',
                style: CustomerTypography.compactStrong,
              ),
            ),
          if (state == AutoCancelState.cancelsSoon) ...[
            const SizedBox(height: 8),
            Text(
              countdown,
              style: CustomerTypography.section.copyWith(
                color: const Color(0xFFB14D22),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!, style: CustomerTypography.compact),
            TextButton(
              onPressed: reading ? null : reload,
              child: const Text('Retry status'),
            ),
          ],
        ],
      ),
    );
  }
}
