import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import 'booking_estimated_cost.dart';

/// Checkout presentation shared by the live journey and isolated screen browser.
List<Widget> bookingCheckoutContents({
  required BuildContext context,
  required CustomerBookingController controller,
  required ValueChanged<String?> onMethodChanged,
  required VoidCallback onConfirm,
  String? cardLabel,
}) {
  final c = controller;
  return [
    const Text(
      'Payment',
      key: ValueKey('booking-payment-confirmation'),
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: catalogInk,
      ),
    ),
    const SizedBox(height: 10),
    BookingEstimatedCost(
      controller: c,
      showPricingChoices: false,
      compact: true,
      amountFontSize: 20,
    ),
    const SizedBox(height: 10),
    const Text(
      'Choose a payment method',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: catalogInk,
      ),
    ),
    const SizedBox(height: 8),
    RadioGroup<String>(
      groupValue: c.method,
      onChanged: onMethodChanged,
      child: Column(
        children: [
          for (final method in c.availableMethods)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: method,
                enabled: !c.busy,
                dense: true,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -3,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                selected: c.method == method,
                selectedTileColor: const Color(0xFFE7F8F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: c.method == method
                        ? catalogTeal
                        : CustomerColors.border,
                  ),
                ),
                title: Text(
                  switch (method) {
                    'CARD' => 'Credit / Debit Card',
                    'WALLET' => 'BThere Wallet',
                    _ => 'Cash on Hand',
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  method == 'CARD'
                      ? (cardLabel ?? 'Select a saved card')
                      : method == 'WALLET'
                      ? 'Use your available wallet balance'
                      : 'Pay after service',
                  style: const TextStyle(fontSize: 10),
                ),
                secondary: method == 'CARD'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/payment/mastercard.svg',
                            width: 20,
                            height: 16,
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/icons/payment/visa.svg',
                            width: 24,
                            height: 16,
                          ),
                        ],
                      )
                    : method == 'WALLET'
                    ? SvgPicture.asset(
                        'assets/icons/navigation/wallet_selected.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          catalogTeal,
                          BlendMode.srcIn,
                        ),
                        semanticsLabel: 'BThere Wallet',
                      )
                    : const Icon(Icons.payments_outlined, color: catalogTeal),
              ),
            ),
        ],
      ),
    ),
    if (c.usesRequestPolicy)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'You won’t be charged until a provider accepts. You’ll confirm payment after acceptance.',
          style: TextStyle(fontSize: 12, color: catalogMuted),
        ),
      ),
    FilledButtonTheme(
      data: FilledButtonThemeData(
        style: Theme.of(context).filledButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: CustomerTypography.family,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: BThereButton(
        key: const ValueKey('booking-confirm-and-pay'),
        label: 'Confirm and Pay',
        loading: c.busy,
        onPressed: c.busy ? null : onConfirm,
      ),
    ),
  ];
}
