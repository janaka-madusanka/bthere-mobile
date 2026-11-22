import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_booking_history.dart';
import '../application/customer_booking_progress_controller.dart';
import '../../wallet/application/customer_wallet_controller.dart';

class CustomerBookingProgress extends ConsumerStatefulWidget {
  const CustomerBookingProgress({
    super.key,
    required this.booking,
    this.onBookingChanged,
    this.embedded = false,
    this.compact = false,
  });
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>>? onBookingChanged;
  final bool embedded;
  final bool compact;
  @override
  ConsumerState<CustomerBookingProgress> createState() =>
      _CustomerBookingProgressState();
}

class _CustomerBookingProgressState
    extends ConsumerState<CustomerBookingProgress>
    with WidgetsBindingObserver {
  late final CustomerBookingProgressController controller;
  Timer? timer;
  bool _confirmDialogOpen = false;
  bool get foreground =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = CustomerBookingProgressController(
      ref.read(customerBookingRepositoryProvider),
      ref.read(customerAuthControllerProvider),
      widget.booking,
      onChanged: () {
        if (mounted && controller.alive) {
          widget.onBookingChanged?.call(controller.booking);
          ref.invalidate(customerBookingHistoryProvider(controller.owner!));
          if (controller.booking['status'] == 'COMPLETED') {
            ref.invalidate(customerWalletProvider);
          }
        }
      },
    );
    controller.addListener(_changed);
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (foreground) controller.refresh();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmCompletion() async {
    final c = controller;
    if (_confirmDialogOpen || !c.canConfirmCompletion) return;
    setState(() => _confirmDialogOpen = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          key: const ValueKey('completion-confirmation-dialog'),
          backgroundColor: Colors.white,
          scrollable: true,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Has the service been completed?',
            style: CustomerTypography.section,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm only after your provider has finished the service.',
                style: CustomerTypography.body,
              ),
              const SizedBox(height: 12),
              Text(
                c.booking['paymentMethod'] == 'WALLET'
                    ? 'This settles the funds already reserved for this booking and releases the provider’s earnings.'
                    : 'This confirms service completion and releases the provider’s earnings.',
                style: CustomerTypography.compact,
              ),
              const SizedBox(height: 8),
              const Text(
                'No additional payment is made.',
                style: CustomerTypography.compactStrong,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              key: const ValueKey('completion-confirmation-submit'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirm completion'),
            ),
          ],
        ),
      );
      if (mounted && c.alive && confirmed == true) await c.confirmCompletion();
    } finally {
      if (mounted) setState(() => _confirmDialogOpen = false);
    }
  }

  @override
  void didUpdateWidget(CustomerBookingProgress old) {
    super.didUpdateWidget(old);
    controller.updateBooking(widget.booking);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && foreground) controller.refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const states = [
      'CONFIRMED',
      'IN_PROGRESS',
      'AWAITING_COMPLETION_CONFIRMATION',
      'COMPLETED',
    ];
    final current = states.indexOf('${c.booking['status']}');
    if (!c.alive || current < 0) return const SizedBox.shrink();
    const titles = [
      'Ready for your service',
      'Service in progress',
      'Awaiting your confirmation',
      'Service completed',
    ];
    const messages = [
      'Your booking is confirmed. Share the start code when the service is ready to begin.',
      'Your provider has started the service.',
      'Your provider has marked the service as finished. Completion is awaiting your confirmation.',
      'The service has been completed. Your payment status is shown in the payment summary.',
    ];
    const labels = [
      'Booking confirmed',
      'Service started',
      'Provider requested completion',
      'Booking completed',
    ];
    return Container(
      key: const ValueKey('booking-service-progress'),
      margin: widget.embedded
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 14),
      padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.embedded ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: widget.embedded
            ? null
            : Border.all(color: CustomerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            const Row(
              children: [
                Icon(Icons.timeline_rounded, color: CustomerColors.action),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Service progress',
                    style: CustomerTypography.section,
                  ),
                ),
              ],
            ),
          if (!widget.embedded) const SizedBox(height: 12),
          if (!widget.compact || current == 2)
            Text(
              titles[current],
              key: const ValueKey('booking-service-status'),
              style:
                  (widget.embedded
                          ? CustomerTypography.compactStrong
                          : CustomerTypography.card)
                      .copyWith(color: CustomerColors.action),
            ),
          if (!widget.embedded || current == 2 || c.settlementUpdating) ...[
            const SizedBox(height: 6),
            Text(
              c.settlementUpdating
                  ? 'Completion confirmed. Updating the payment summary…'
                  : messages[current],
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.secondaryText,
              ),
            ),
          ],
          SizedBox(height: widget.embedded ? 8 : 14),
          if (!widget.compact)
            LayoutBuilder(
              builder: (context, bounds) {
                final step = current;
                if (bounds.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < states.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(
                                index < step || current == 3
                                    ? Icons.check_circle_rounded
                                    : index == step
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: index <= step
                                    ? CustomerColors.action
                                    : CustomerColors.muted,
                                size: 23,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  labels[index],
                                  style: CustomerTypography.compact.copyWith(
                                    color: index <= step
                                        ? CustomerColors.primary
                                        : CustomerColors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Positioned(
                      top: 12,
                      left: bounds.maxWidth / 8,
                      right: bounds.maxWidth / 8,
                      child: Row(
                        children: [
                          for (var index = 1; index < states.length; index++)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index <= step
                                    ? CustomerColors.action
                                    : CustomerColors.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < states.length; index++)
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: Colors.white,
                                  child: Icon(
                                    index < step || current == 3
                                        ? Icons.check_circle_rounded
                                        : index == step
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: index <= step
                                        ? CustomerColors.action
                                        : CustomerColors.muted,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  labels[index],
                                  textAlign: TextAlign.center,
                                  style: CustomerTypography.micro.copyWith(
                                    color: index <= step
                                        ? CustomerColors.primary
                                        : CustomerColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          if (current == 2) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('booking-confirm-completion'),
              onPressed: c.canConfirmCompletion && !_confirmDialogOpen
                  ? _confirmCompletion
                  : null,
              icon: c.working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt_rounded),
              label: Text(
                c.working
                    ? 'Confirming completion…'
                    : 'Confirm service completion',
              ),
            ),
          ],
          if (c.completionError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                c.completionError!,
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.secondaryText,
                ),
              ),
            ),
          if (c.completionUncertain)
            TextButton(
              onPressed: c.working ? null : c.refresh,
              child: const Text('Check completion status'),
            ),
          if (c.error != null) ...[
            Text(
              c.error!,
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.secondaryText,
              ),
            ),
            TextButton(
              onPressed: c.refresh,
              child: const Text('Check service status'),
            ),
          ],
        ],
      ),
    );
  }
}
