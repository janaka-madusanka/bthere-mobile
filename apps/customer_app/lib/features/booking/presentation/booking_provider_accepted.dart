import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import '../domain/booking_models.dart';

/// Presentation only; the request controller owns acceptance and its deadline.
class BookingProviderAccepted extends StatelessWidget {
  const BookingProviderAccepted({
    super.key,
    required this.serviceName,
    required this.provider,
    required this.deadline,
    required this.expired,
    required this.busy,
    required this.availableHeight,
    required this.onContinue,
    this.onCancel,
    this.paymentAmount,
    this.paymentMethod = 'WALLET',
    this.error,
  });

  final String serviceName;
  final ProviderCandidate? provider;
  final String? deadline;
  final bool expired, busy;
  final double availableHeight;
  final VoidCallback onContinue;
  final VoidCallback? onCancel;
  final String? paymentAmount;
  final String paymentMethod;
  final String? error;

  static const _ink = Color(0xFF0C1248);

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          const Text(
            'We found a provider!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A provider has accepted your request.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: CustomerColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Image.asset(
            'assets/illustrations/booking/provider_accepted.png',
            height: math.min(260, availableHeight * .29),
            fit: BoxFit.contain,
            semanticLabel: 'Happy bee holding a provider badge',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCEFF0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x09006068),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: provider?.photo == null
                            ? _avatarFallback
                            : Image.network(
                                provider!.photo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _avatarFallback,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider?.name ?? 'Your provider',
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (provider?.data['averageRating'] is num)
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 17,
                                  color: Color(0xFFF5B83D),
                                ),
                                Text(
                                  '${provider!.data['averageRating']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                if (provider!.data['totalRatings'] is int)
                                  Text(
                                    '(${provider!.data['totalRatings']} ratings)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: CustomerColors.secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.work_outline_rounded,
                      size: 15,
                      color: CustomerColors.action,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFE8F1F2)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: expired
                        ? const Color(0xFFFFF2F2)
                        : CustomerColors.selection,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD7F2F2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 32,
                              color: expired
                                  ? const Color(0xFFB74C59)
                                  : CustomerColors.action,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Confirm payment before',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                  ),
                                ),
                                if (deadline != null)
                                  Text(
                                    deadline!,
                                    style: TextStyle(
                                      fontSize: 38,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: expired
                                          ? const Color(0xFFB74C59)
                                          : const Color(0xFF087E9A),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expired
                            ? 'Confirmation time has expired. Refresh the request status.'
                            : paymentAmount != null
                            ? paymentMethod == 'CARD'
                                  ? 'Continue to secure card payment.'
                                  : 'Confirm below to pay with BThere Wallet.'
                            : 'You’ll confirm the payment in the next step.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (paymentAmount != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5FAFA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (paymentMethod == 'CARD')
                          const Icon(
                            Icons.credit_card_rounded,
                            size: 24,
                            color: CustomerColors.action,
                          )
                        else
                          SvgPicture.asset(
                            'assets/icons/navigation/wallet_selected.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              CustomerColors.action,
                              BlendMode.srcIn,
                            ),
                            semanticsLabel: 'BThere Wallet',
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paymentMethod == 'CARD'
                                    ? 'Credit / Debit Card'
                                    : 'BThere Wallet',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CustomerColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                paymentAmount!,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (error != null) ...[
                  Container(
                    key: const ValueKey('booking-accepted-payment-error'),
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                FilledButton(
                  key: const ValueKey('booking-accepted-continue'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy || (paymentAmount != null && expired)
                      ? null
                      : onContinue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          paymentAmount != null
                              ? (busy
                                    ? 'Confirming payment...'
                                    : 'Confirm and Pay')
                              : 'Continue to payment',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!busy) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    key: const ValueKey('booking-cancel-request'),
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE54D61),
                      backgroundColor: const Color(0xFFFFEFF2),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    label: const Text(
                      'Cancel request',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget get _avatarFallback => const ColoredBox(
    color: CustomerColors.selection,
    child: Icon(
      Icons.person_outline_rounded,
      color: CustomerColors.action,
      size: 32,
    ),
  );
}
