import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import '../../wallet/data/customer_wallet_repository.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_booking_history.dart';
import '../application/customer_cancellation_controller.dart';
import '../domain/booking_cancellation.dart';

class CustomerBookingCancellation extends ConsumerStatefulWidget {
  const CustomerBookingCancellation({
    super.key,
    required this.booking,
    required this.onChanged,
  });
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  ConsumerState<CustomerBookingCancellation> createState() =>
      _CustomerBookingCancellationState();
}

class _CustomerBookingCancellationState
    extends ConsumerState<CustomerBookingCancellation> {
  late final CustomerCancellationController c;
  bool dialogOpen = false;
  @override
  void initState() {
    super.initState();
    c = CustomerCancellationController(
      ref.read(customerBookingRepositoryProvider),
      ref.read(customerAuthControllerProvider),
      widget.booking,
      onChanged: () {
        if (!mounted || !c.alive) return;
        widget.onChanged(c.booking);
        ref.invalidate(customerBookingHistoryProvider(c.owner!));
        ref.invalidate(customerWalletProvider);
      },
    );
    c.addListener(changed);
    if (widget.booking['status'] == 'CANCELLED') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.loadReceipt();
      });
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CustomerBookingCancellation old) {
    super.didUpdateWidget(old);
    c.update(widget.booking);
  }

  Future<void> review() async {
    if (dialogOpen || c.working || !c.eligible) return;
    dialogOpen = true;
    try {
      if (!await c.prepare() || !mounted || !c.alive) return;
      final result = await showModalBottomSheet<(String, String)>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _CancellationReview(preview: c.preview!),
      );
      if (mounted && c.alive && result != null) {
        await c.confirm(result.$1, result.$2);
      }
    } finally {
      dialogOpen = false;
    }
  }

  @override
  void dispose() {
    c.removeListener(changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!c.alive) return const SizedBox.shrink();
    final receipt = c.receipt, data = receipt?.data;
    if (receipt == null && c.eligible) return _compactCancellation();
    return Container(
      key: const ValueKey('booking-cancellation-section'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.eligible ? const Color(0xFFFFF3F3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F666B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFE8EC),
                child: Icon(
                  Icons.event_busy_outlined,
                  color: CustomerColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  receipt == null
                      ? 'Cancel booking'
                      : data!['cancelledBy'] == 'PROVIDER'
                      ? 'Your provider cancelled this booking'
                      : 'Booking cancelled',
                  style: CustomerTypography.card.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101D42),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (receipt != null) ...[
            Container(
              key: const ValueKey('cancellation-refund-summary'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F8F6), Color(0xFFF0FBFA)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/navigation/wallet.svg',
                      colorFilter: const ColorFilter.mode(
                        CustomerColors.action,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.refund == 0
                              ? 'No wallet refund'
                              : 'Refunded to your wallet',
                          style: CustomerTypography.compactStrong.copyWith(
                            color: CustomerColors.action,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          receipt.money('refundAmount'),
                          style: CustomerTypography.section.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF101D42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _receiptRow('Amount paid', receipt.money('paidAmount')),
            _receiptRow('Cancellation fee', receipt.money('cancellationFee')),
            if (data!['refundTierName'] is String)
              _receiptRow('Refund policy', data['refundTierName'] as String),
            if (data['reason'] is String)
              _receiptRow('Reason', data['reason'] as String),
            if (data['note'] is String &&
                (data['note'] as String).trim().isNotEmpty)
              _receiptRow('Your note', data['note'] as String),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: CustomerColors.action,
                    size: 18,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Refunds for card and wallet payments are credited to your BThere Wallet.',
                      style: CustomerTypography.compact,
                    ),
                  ),
                ],
              ),
            ),
            if (data['penalty'] case final Map penalty) ...[
              const SizedBox(height: 8),
              Text(
                'Compensation credited: ${data['currencyCode']} ${walletMoney(penalty['customerPaidAmount']).replaceFirst('Rs. ', '')}',
                style: CustomerTypography.card,
              ),
              if (walletMinorUnits(penalty['customerPaidAmount']) <
                  walletMinorUnits(penalty['customerShareAmount']))
                const Text(
                  'Additional compensation will be credited when recovered from the provider.',
                  style: CustomerTypography.compact,
                ),
              TextButton(
                onPressed: c.working ? null : c.loadReceipt,
                child: const Text('Check compensation'),
              ),
            ],
          ] else if (c.eligible) ...[
            const Text(
              'Review your wallet refund before cancelling. Available until the service starts.',
              style: CustomerTypography.compact,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('booking-review-cancellation'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CustomerColors.error,
                side: const BorderSide(color: Color(0xFFF2AAA9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: c.working || c.uncertain ? null : review,
              child: Text(c.working ? 'Checking…' : 'Cancel booking'),
            ),
          ],
          if (c.working && !c.eligible && receipt == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loading cancellation details',
                      style: CustomerTypography.compact,
                    ),
                  ),
                ],
              ),
            ),
          if (c.error != null)
            Text(
              c.error!,
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.error,
              ),
            ),
          if (c.uncertain ||
              receipt == null &&
                  c.booking['status'] == 'CANCELLED' &&
                  c.error != null)
            TextButton(
              onPressed: c.working ? null : c.loadReceipt,
              child: const Text('Check cancellation status'),
            ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFECF1F3))),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final caption = Text(
          label,
          style: CustomerTypography.compact.copyWith(
            color: CustomerColors.secondaryText,
          ),
        );
        final content = Text(
          value,
          style: CustomerTypography.compactStrong.copyWith(
            color: const Color(0xFF101D42),
            fontWeight: FontWeight.w700,
          ),
        );
        if (bounds.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, const SizedBox(height: 4), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: caption),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: content),
          ],
        );
      },
    ),
  );

  Widget _compactCancellation() => Padding(
    key: const ValueKey('booking-cancellation-section'),
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: TextButton(
            key: const ValueKey('booking-review-cancellation'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB45158),
              textStyle: CustomerTypography.compactStrong,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: c.working || c.uncertain ? null : review,
            child: Text(c.working ? 'Checking?' : 'Cancel booking'),
          ),
        ),
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              c.error!,
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.error,
              ),
            ),
          ),
        if (c.uncertain)
          TextButton(
            onPressed: c.working ? null : c.loadReceipt,
            child: const Text('Check cancellation status'),
          ),
      ],
    ),
  );
}

class _CancellationReview extends StatefulWidget {
  const _CancellationReview({required this.preview});
  final BookingCancellation preview;
  @override
  State<_CancellationReview> createState() => _CancellationReviewState();
}

class _CancellationReviewState extends State<_CancellationReview> {
  bool closing = false;
  final form = GlobalKey<FormState>();
  String? selectedReason;
  final reason = TextEditingController(), note = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    note.dispose();
    super.dispose();
  }

  Future<String?> _chooseReason() => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cancellation reason',
              style: CustomerTypography.section,
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the reason that best describes your situation.',
              style: CustomerTypography.compact,
            ),
            const SizedBox(height: 16),
            for (final label in [
              'Plans changed',
              'Booked by mistake',
              'Service no longer needed',
              'Other',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: label == selectedReason
                      ? CustomerColors.selection
                      : const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(sheetContext, label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: label == selectedReason
                                  ? CustomerTypography.card
                                  : CustomerTypography.body,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            label == selectedReason
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: label == selectedReason
                                ? CustomerColors.action
                                : CustomerColors.muted,
                            size: 22,
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final keep = FilledButton(
      onPressed: closing ? null : () => Navigator.pop(context),
      style: FilledButton.styleFrom(
        backgroundColor: CustomerColors.action,
        foregroundColor: Colors.white,
        textStyle: CustomerTypography.card.copyWith(
          fontWeight: FontWeight.w700,
        ),
        minimumSize: const Size.fromHeight(48),
      ),
      child: const Text('Keep booking'),
    );
    final cancel = FilledButton(
      key: const ValueKey('confirm-paid-cancellation'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFEDEE),
        foregroundColor: const Color(0xFFB45158),
        textStyle: CustomerTypography.card,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: closing
          ? null
          : () {
              if (form.currentState!.validate()) {
                setState(() => closing = true);
                Navigator.pop(context, (
                  selectedReason == 'Other'
                      ? reason.text.trim()
                      : selectedReason!,
                  note.text.trim(),
                ));
              }
            },
      child: const Text('Cancel Booking'),
    );
    return SingleChildScrollView(
      key: const ValueKey('paid-cancellation-review'),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: CustomerColors.error,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cancel Booking', style: CustomerTypography.screen),
                      SizedBox(height: 4),
                      Text(
                        'Tell us why you want to cancel this booking.',
                        style: CustomerTypography.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FormField<String>(
              initialValue: selectedReason,
              validator: (value) =>
                  value == null ? 'Select a cancellation reason.' : null,
              builder: (field) => InkWell(
                key: const ValueKey('cancellation-reason'),
                borderRadius: BorderRadius.circular(14),
                onTap: closing
                    ? null
                    : () async {
                        final value = await _chooseReason();
                        if (!mounted || value == null) return;
                        field.didChange(value);
                        setState(() => selectedReason = value);
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Cancellation reason',
                    errorText: field.errorText,
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    prefixIcon: const Icon(
                      Icons.list_alt_rounded,
                      color: CustomerColors.action,
                    ),
                    suffixIcon: const Icon(
                      Icons.expand_more_rounded,
                      color: CustomerColors.action,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    selectedReason ?? 'Select a reason',
                    style: CustomerTypography.body,
                  ),
                ),
              ),
            ),
            if (selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (v) => v?.trim().isEmpty != false
                    ? 'Enter a cancellation reason.'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: note,
              maxLength: 1000,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                border: Border.all(color: const Color(0xFFD5EEEB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: CustomerColors.action,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refund preview',
                          style: CustomerTypography.compactStrong.copyWith(
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${preview.money('refundAmount')} back to your wallet",
                          style: CustomerTypography.card.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (preview.data['retainedAmount'] != null)
                          Text(
                            "${preview.money('retainedAmount')} retained",
                            style: CustomerTypography.compact,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          "Cancellation fee: ${preview.money('cancellationFee')}",
                          style: CustomerTypography.compact,
                        ),
                        const SizedBox(height: 4),
                        if (preview.data['refundTierName'] is String)
                          Text(
                            "Refund policy: ${preview.data['refundTierName']}",
                            style: CustomerTypography.compact,
                          ),
                        const Divider(height: 20, color: Color(0xFFD5EEEB)),
                        const Text(
                          'Any applicable refund goes to your BThere Wallet, including payments made by card.',
                          style: CustomerTypography.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, bounds) =>
                  bounds.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [keep, const SizedBox(height: 10), cancel],
                    )
                  : Row(
                      children: [
                        Expanded(child: keep),
                        const SizedBox(width: 12),
                        Expanded(child: cancel),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
