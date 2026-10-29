import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';

/// Read-only estimate: never selects a provider/payment method or creates a job.
class BookingEstimatedCost extends StatefulWidget {
  const BookingEstimatedCost({
    super.key,
    required this.controller,
    this.showPricingChoices = true,
    this.compact = false,
  });
  final CustomerBookingController controller;
  final bool showPricingChoices;
  final bool compact;
  @override
  State<BookingEstimatedCost> createState() => _BookingEstimatedCostState();
}

class _BookingEstimatedCostState extends State<BookingEstimatedCost> {
  Timer? _timer;
  int _generation = 0;
  String? _fingerprint, _message;
  Map<String, dynamic>? _quote;
  bool _loading = false, _failed = false;
  CustomerBookingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(covariant BookingEstimatedCost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != c) {
      oldWidget.controller.removeListener(_changed);
      c.addListener(_changed);
      _fingerprint = null;
      _changed();
    }
  }

  void _changed({bool retry = false}) {
    Map<String, Object?>? input;
    String? message;
    if (!c.alive || c.context == null || !c.allowed) {
      message = 'Complete the service requirements to see an estimate.';
    } else if (c.isOpenRequest) {
      try {
        input = c.openEstimateInput();
      } on BookingProblem catch (failure) {
        message = failure.message;
      } catch (_) {
        message = 'Complete your schedule and location to see an estimate.';
      }
    } else if (c.context!.fields.any(
      (f) => f.applies(c.answers) && f.validate(c.answers[f.code]) != null,
    )) {
      message = 'Complete booking details to see your estimated cost.';
    } else {
      try {
        // The quote endpoint requires a supported payment method. Use an
        // allowed method for estimation only; keep the user's choice untouched.
        input = c.bookingInput(
          quotePaymentMethod: c.method ?? c.availableMethods.firstOrNull,
        );
      } catch (_) {
        message =
            'Complete your schedule and pricing choices to see an estimate.';
      }
    }
    final fingerprint = input == null ? message : jsonEncode(input);
    if (!retry && fingerprint == _fingerprint) return;
    _fingerprint = fingerprint;
    _timer?.cancel();
    final generation = ++_generation;
    setState(() {
      _quote = null;
      _message = message;
      _failed = false;
      _loading = input != null;
    });
    if (input != null) {
      final request = input;
      final openRequest = c.isOpenRequest;
      _timer = Timer(
        const Duration(milliseconds: 500),
        () => _fetch(request, generation, openRequest),
      );
    }
  }

  Future<void> _fetch(
    Map<String, Object?> input,
    int generation,
    bool openRequest,
  ) async {
    try {
      final quote = openRequest
          ? await c.repository.estimate(input)
          : await c.repository.quote(input);
      if (!mounted || !c.alive || generation != _generation) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted || !c.alive || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
        _message = failure is BookingProblem && failure.status == 404
            ? 'A price estimate is not available for this service yet.'
            : failure is BookingProblem && failure.status == 400
            ? 'Check the selected time, location and pricing choices.'
            : 'Estimate unavailable right now.';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    c.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showPricingChoices) BookingPricingChoices(controller: c),
      Container(
        key: const ValueKey('booking-estimated-cost'),
        margin: widget.compact
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 6),
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 7)
            : const EdgeInsets.all(12),
        decoration: widget.compact
            ? BoxDecoration(
                color: const Color(0xFFEDF9F9),
                borderRadius: BorderRadius.circular(12),
              )
            : BoxDecoration(
                color: CustomerColors.selection,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CustomerColors.border),
              ),
        child: Row(
          children: [
            if (!widget.compact)
              const Icon(
                Icons.payments_outlined,
                color: CustomerColors.action,
                size: 26,
              ),
            if (!widget.compact) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated cost',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _loading
                        ? 'Calculating…'
                        : _quote == null
                        ? _message ?? 'Not available yet'
                        : _quote!['currencyCode'] == 'LKR'
                        ? walletMoney(_quote!['expectedAmount'])
                        : '${_quote!['currencyCode']} ${_quote!['expectedAmount']}',
                    style: TextStyle(
                      fontSize: _quote == null
                          ? 12
                          : widget.compact
                          ? 16
                          : 21,
                      fontWeight: _quote == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: CustomerColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_failed)
              IconButton(
                tooltip: 'Retry estimate',
                onPressed: () => _changed(retry: true),
                icon: const Icon(Icons.refresh, color: CustomerColors.action),
              ),
          ],
        ),
      ),
    ],
  );
}

class BookingPricingChoices extends StatelessWidget {
  const BookingPricingChoices({super.key, required this.controller});
  final CustomerBookingController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in c.context!.providerFilters.where(
          (f) => c.context!.pricingFieldIds.contains(f.id),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'details-pricing-${field.id}-${c.pricingSelections[field.id]}',
              ),
              initialValue: c.pricingSelections[field.id],
              decoration: InputDecoration(
                labelText: field.label,
                isDense: true,
              ),
              items: [
                for (final choice in field.options)
                  DropdownMenuItem(
                    value: choice['value'],
                    child: Text(choice['label']!),
                  ),
              ],
              onChanged: c.busy
                  ? null
                  : (value) => c.choosePricing(field.id, value),
            ),
          ),
      ],
    );
  }
}
