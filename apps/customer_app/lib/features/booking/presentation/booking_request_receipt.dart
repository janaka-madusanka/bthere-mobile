import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'booking_payment_pending.dart';
import 'booking_payment_confirmation.dart';
import 'booking_confirmed_view.dart';
import 'booking_request_closed.dart';

import '../../../app/customer_theme.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;

/// Shared presentation; the server and existing callbacks own payment behavior.
class BookingRequestReceipt extends StatelessWidget {
  const BookingRequestReceipt({
    super.key,
    required this.request,
    required this.onRefresh,
    required this.onConfirmWallet,
    required this.onHome,
    this.onBookingForm,
    this.onBookingDetails,
    this.onSendAgain,
    this.onBookingFilters,
    this.busy = false,
  });
  final Map<String, dynamic> request;
  final bool busy;
  final VoidCallback onRefresh, onConfirmWallet, onHome;
  final VoidCallback? onBookingForm;
  final VoidCallback? onBookingDetails;
  final VoidCallback? onSendAgain;
  final VoidCallback? onBookingFilters;
  static const ink = Color(0xFF0C1248);

  @override
  Widget build(BuildContext context) {
    final status = request['status'];
    final confirmed =
        status == 'CONFIRMED' &&
        {'RESERVED', 'PAID', 'SETTLED'}.contains(request['paymentStatus']);
    final awaiting = status == 'AWAITING_CUSTOMER_CONFIRMATION';
    final pending = status == 'PAYMENT_PENDING';
    final closed = status == 'CANCELLED' || status == 'EXPIRED';
    final wallet = request['paymentMethod'] == 'WALLET';
    final title = switch (status) {
      'AWAITING_CUSTOMER_CONFIRMATION' => 'Confirm your payment',
      'PAYMENT_PENDING' => 'Checking your payment',
      'CONFIRMED' when confirmed => 'Your booking is confirmed',
      'CANCELLED' => 'Request cancelled',
      'EXPIRED' => 'Request expired',
      'MATCHING' => 'Finding your provider',
      _ => 'Your booking request',
    };
    final message = switch (status) {
      'AWAITING_CUSTOMER_CONFIRMATION' =>
        'Your provider has accepted. Confirm payment to secure your booking.',
      'PAYMENT_PENDING' => 'We are checking the payment result. Refresh the status before trying again.',
      'CONFIRMED' when confirmed =>
        request['paymentStatus'] == 'RESERVED'
            ? 'Your wallet funds are reserved for this booking.'
            : 'Your payment has been confirmed.',
      'CANCELLED' => 'This request has been cancelled. You can return home when you are ready.',
      'EXPIRED' => 'The confirmation window has ended. Refresh to see the latest request status.',
      'MATCHING' => 'Payment can be confirmed after a provider accepts.',
      _ => 'Refresh to see the latest booking and payment status.',
    };
    final amount = request['expectedAmount'];
    final currency = request['currencyCode'];
    final amountLabel = amount == null
        ? null
        : walletMoney(amount)
              .replaceFirst(
                'Rs.',
                currency == 'LKR' ? 'Rs.' : '${currency ?? ''}',
              )
              .trim();
    if (status == 'EXPIRED' || status == 'CANCELLED' || status == 'UNMATCHED') {
      return BookingRequestClosed(
        cancelled: status == 'CANCELLED',
        unmatched: status == 'UNMATCHED',
        requestId: request['requestId'],
        amount: amountLabel,
        method: '${request['paymentMethod'] ?? 'Not selected'}',
        busy: busy,
        onHome: onHome,
        onBookingForm: onBookingForm,
        onBookingFilters: onBookingFilters,
        onSendAgain: onSendAgain,
      );
    }
    if (confirmed) {
      return BookingConfirmedView(
        requestId: request['requestId'],
        amount: amountLabel,
        method: '${request['paymentMethod'] ?? 'Not selected'}',
        paymentStatus: '${request['paymentStatus']}',
        busy: busy,
        onBookingDetails: onBookingDetails,
        onHome: onHome,
      );
    }
    if (pending) {
      return BookingPaymentPending(
        requestId: request['requestId'],
        amount: amountLabel,
        method: '${request['paymentMethod'] ?? 'Not selected'}',
        busy: busy,
        onRefresh: onRefresh,
      );
    }
    if (awaiting) {
      return BookingPaymentConfirmation(
        requestId: request['requestId'],
        amount: amountLabel,
        method: '${request['paymentMethod'] ?? 'Not selected'}',
        busy: busy,
        onPay: onConfirmWallet,
        onHome: onHome,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: CustomerColors.selection,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  confirmed
                      ? Icons.check_circle_outline_rounded
                      : closed
                      ? Icons.event_busy_outlined
                      : Icons.lock_outline_rounded,
                  color: CustomerColors.action,
                  size: 27,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Request #${request['requestId']}',
              style: const TextStyle(
                fontSize: 12,
                color: CustomerColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            if (amountLabel != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F7F7), Color(0xFFF0FBFB)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD7EDEE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      confirmed ? 'Booking amount' : 'Amount to pay',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      amountLabel,
                      style: const TextStyle(
                        fontSize: 29,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const Text(
              'Payment method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCEBED)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CustomerColors.selection,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: wallet
                        ? SvgPicture.asset(
                            'assets/icons/navigation/wallet_selected.svg',
                            colorFilter: const ColorFilter.mode(
                              CustomerColors.action,
                              BlendMode.srcIn,
                            ),
                          )
                        : const Icon(
                            Icons.credit_card_rounded,
                            color: CustomerColors.action,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet
                              ? 'BThere Wallet'
                              : request['paymentMethod'] == 'CARD'
                              ? 'Credit / Debit Card'
                              : '${request['paymentMethod'] ?? 'Not selected'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          wallet
                              ? 'Your selected wallet'
                              : 'Your selected payment method',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: CustomerColors.action,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: closed
                    ? const Color(0xFFFFF3F1)
                    : const Color(0xFFF0F7F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    confirmed
                        ? Icons.check_circle_outline
                        : pending
                        ? Icons.hourglass_top_rounded
                        : Icons.info_outline,
                    size: 18,
                    color: CustomerColors.action,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: CustomerColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (wallet && awaiting) ...[
              FilledButton.icon(
                key: const ValueKey('booking-confirm-wallet'),
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
                onPressed: busy ? null : onConfirmWallet,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  busy ? 'Confirming payment...' : 'Confirm and Pay',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Refresh request status',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy ? null : onHome,
              child: const Text('Back to Home', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
