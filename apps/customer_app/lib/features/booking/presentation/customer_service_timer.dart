import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_providers.dart';
import '../../../app/customer_theme.dart';

DateTime? serviceTimerInstant(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// Actual service time only: scheduled dates never start or stop this clock.
class CustomerServiceTimer extends ConsumerStatefulWidget {
  const CustomerServiceTimer({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  ConsumerState<CustomerServiceTimer> createState() => _ServiceTimerState();
}

class _ServiceTimerState extends ConsumerState<CustomerServiceTimer>
    with WidgetsBindingObserver {
  Timer? ticker;
  bool get foreground =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  void syncTicker() {
    ticker?.cancel();
    if (widget.booking['status'] == 'IN_PROGRESS' &&
        serviceTimerInstant(widget.booking['actualStartedAt']) != null &&
        widget.booking['actualFinishedAt'] == null) {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (foreground) setState(() {});
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncTicker();
  }

  @override
  void didUpdateWidget(CustomerServiceTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncTicker();
      if (mounted) setState(() {});
    } else {
      ticker?.cancel();
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
    final booking = widget.booking;
    final status = booking['status'];
    if (!{
      'IN_PROGRESS',
      'AWAITING_COMPLETION_CONFIRMATION',
      'COMPLETED',
    }.contains(status)) {
      return const SizedBox.shrink();
    }
    final start = serviceTimerInstant(booking['actualStartedAt']);
    final finish = serviceTimerInstant(booking['actualFinishedAt']);
    if (start == null ||
        (status != 'IN_PROGRESS' && finish == null) ||
        (booking['actualFinishedAt'] != null && finish == null)) {
      return const SizedBox.shrink();
    }
    final end = finish ?? ref.read(customerClockProvider)().toUtc();
    if (end.isBefore(start)) return const SizedBox.shrink();
    final elapsed = end.difference(start).inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(elapsed ~/ 3600)}:${two(elapsed ~/ 60 % 60)}:${two(elapsed % 60)}';
    final label = finish == null ? 'Elapsed service time' : 'Service duration';
    return Container(
      key: const ValueKey('booking-service-timer'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 22,
                color: CustomerColors.action,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, style: CustomerTypography.compactStrong),
              ),
            ],
          ),
          Text(
            time,
            style: CustomerTypography.section.copyWith(
              color: const Color(0xFF101D42),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
