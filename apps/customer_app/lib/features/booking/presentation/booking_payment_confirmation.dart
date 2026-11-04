import 'package:flutter/material.dart';

import 'booking_payment_visuals.dart';

class BookingPaymentConfirmation extends StatelessWidget {
  const BookingPaymentConfirmation({
    super.key,
    required this.requestId,
    required this.amount,
    required this.method,
    required this.busy,
    required this.onPay,
    required this.onHome,
  });
  final Object? requestId;
  final String? amount;
  final String method;
  final bool busy;
  final VoidCallback onPay, onHome;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentArtHeading(
            title: 'Confirm your payment',
            requestId: requestId,
          ),
          const SizedBox(height: 22),
          if (amount != null) ...[
            PaymentAmountArtwork(amount: amount!),
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
            title: 'Your provider has accepted!',
            message: 'Confirm payment to secure your booking.',
          ),
          const SizedBox(height: 24),
          if (method == 'WALLET' || method == 'CARD') ...[
            FilledButton(
              key: ValueKey(
                method == 'CARD'
                    ? 'booking-confirm-card'
                    : 'booking-confirm-wallet',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : onPay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      busy ? 'Confirming payment...' : 'Confirm and Pay',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!busy) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextButton(
            onPressed: busy ? null : onHome,
            child: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
