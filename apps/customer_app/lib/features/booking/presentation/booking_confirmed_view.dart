import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import 'booking_payment_visuals.dart';

/// Only shown for the server-confirmed request and confirmed payment statuses.
class BookingConfirmedView extends StatelessWidget {
  const BookingConfirmedView({
    super.key,
    required this.requestId,
    required this.amount,
    required this.method,
    required this.paymentStatus,
    required this.busy,
    this.onBookingDetails,
    required this.onHome,
  });
  final Object? requestId;
  final String? amount;
  final String method, paymentStatus;
  final bool busy;
  final VoidCallback onHome;
  final VoidCallback? onBookingDetails;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentArtHeading(
            title: 'Your booking is confirmed!',
            requestId: requestId,
            artwork:
                'assets/illustrations/booking/booking_confirmed_mascot.png',
            artworkLabel: 'Happy bee holding a booking confirmation badge',
          ),
          const SizedBox(height: 24),
          if (amount != null) ...[
            PaymentAmountArtwork(
              amount: amount!,
              label: 'Booking amount',
              banner: false,
            ),
            const SizedBox(height: 22),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CustomerColors.selection,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: CustomerColors.action,
                  size: 23,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    paymentStatus == 'RESERVED'
                        ? method == 'WALLET'
                              ? 'Your wallet funds are reserved for this booking.'
                              : 'Funds are reserved for this booking.'
                        : 'Your payment has been confirmed.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          if (onBookingDetails != null)
            FilledButton.icon(
              key: const ValueKey('booking-confirmed-details'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : onBookingDetails,
              icon: const Icon(Icons.receipt_long_outlined, size: 21),
              label: const Text(
                'View booking details',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: busy ? null : onHome,
            child: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
