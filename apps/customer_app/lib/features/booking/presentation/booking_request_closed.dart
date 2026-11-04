import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import 'booking_payment_visuals.dart';

/// Server-closed request presentation with read-only status recovery actions.
class BookingRequestClosed extends StatelessWidget {
  const BookingRequestClosed({
    super.key,
    required this.requestId,
    required this.cancelled,
    required this.amount,
    required this.method,
    required this.busy,
    required this.onHome,
    this.onBookingForm,
    this.onSendAgain,
    this.unmatched = false,
    this.onBookingFilters,
  });
  final Object? requestId;
  final String? amount;
  final String method;
  final bool busy, cancelled;
  final VoidCallback onHome;
  final VoidCallback? onBookingForm;
  final VoidCallback? onSendAgain;
  final bool unmatched;
  final VoidCallback? onBookingFilters;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentArtHeading(
            title: unmatched
                ? 'No provider accepted'
                : cancelled
                ? 'Request cancelled'
                : 'Request expired',
            requestId: requestId,
            artwork: cancelled
                ? 'assets/illustrations/booking/request_cancelled_mascot.png'
                : 'assets/illustrations/booking/request_expired_mascot.png',
            artworkLabel: unmatched
                ? 'Bee holding an unsuccessful request calendar'
                : cancelled
                ? 'Bee holding a cancelled calendar'
                : 'Bee holding an expired calendar',
          ),
          const SizedBox(height: 24),
          if (amount != null) ...[
            PaymentAmountArtwork(
              amount: amount!,
              label: 'Request amount',
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
              border: Border.all(
                color: CustomerColors.action.withValues(alpha: .15),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cancelled || unmatched
                      ? Icons.info_outline_rounded
                      : Icons.schedule_rounded,
                  color: CustomerColors.action,
                  size: 27,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: cancelled
                      ? const Text(
                          'This request has been cancelled. You can edit your booking details or return home.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: CustomerColors.text,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unmatched
                                  ? 'No provider accepted this request.'
                                  : 'The confirmation window has expired.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: CustomerColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              unmatched
                                  ? 'Send it again or change your filters. Your booking details are kept.'
                                  : 'Return to your booking form to review your details.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: CustomerColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          if (!cancelled && onSendAgain != null) ...[
            FilledButton.icon(
              key: ValueKey(
                unmatched
                    ? 'booking-unmatched-send-again'
                    : 'booking-expired-send-again',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: busy ? null : onSendAgain,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined, size: 21),
              label: Text(busy ? 'Sending request...' : 'Send request again'),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            key: ValueKey(
              unmatched
                  ? 'booking-unmatched-filters'
                  : cancelled
                  ? 'booking-cancelled-edit'
                  : 'booking-expired-edit',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: cancelled ? null : Colors.white,
              foregroundColor: cancelled ? null : CustomerColors.action,
              side: cancelled
                  ? null
                  : const BorderSide(color: CustomerColors.action),
            ),
            onPressed: busy
                ? null
                : unmatched
                ? onBookingFilters
                : onBookingForm,
            icon: Icon(
              unmatched ? Icons.tune_rounded : Icons.edit_calendar_outlined,
              size: 21,
            ),
            label: Text(unmatched ? 'Change filters' : 'Back to booking form'),
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
