import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/customer_theme.dart';
import 'booking_payment_result_screen.dart';

const paymentInk = Color(0xFF0C1248);
const paymentArt = 'assets/illustrations/payment/';

class BookingPaymentPage extends StatelessWidget {
  const BookingPaymentPage({super.key, required this.child, this.onBack});
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF007E83),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text(
        'Get a Service',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: Colors.white,
        child: BookingFlowBackdrop(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (bounds.maxHeight - 46).clamp(0, double.infinity),
                ),
                child: SafeArea(top: false, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PaymentArtHeading extends StatelessWidget {
  const PaymentArtHeading({
    super.key,
    required this.title,
    required this.requestId,
    this.subtitle,
    this.artwork = '${paymentArt}secure_payment_mascot.png',
    this.artworkLabel = 'Bee protecting a secure payment',
  });
  final String title;
  final Object? requestId;
  final String? subtitle;
  final String artwork, artworkLabel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        artwork,
        height: 142,
        fit: BoxFit.contain,
        semanticLabel: artworkLabel,
      ),
      const SizedBox(height: 10),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 25,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: paymentInk,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'Request #$requestId',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: CustomerColors.secondaryText,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 8),
        Text(
          subtitle!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: CustomerColors.secondaryText,
          ),
        ),
      ],
    ],
  );
}

class PaymentAmountArtwork extends StatelessWidget {
  const PaymentAmountArtwork({
    super.key,
    required this.amount,
    this.label = 'Amount to pay',
    this.banner = false,
  });
  final String amount, label;
  final bool banner;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final compact =
          bounds.maxWidth < 350 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final showArtwork =
          bounds.maxWidth >= 280 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      final artworkWidth = bounds.maxWidth < 350 ? 76.0 : 100.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(
              child: banner
                  ? Image.asset(
                      '${paymentArt}payment_amount_banner.png',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE2F8F8), Color(0xFFD3F3F3)],
                        ),
                      ),
                    ),
            ),
            if (!banner && showArtwork)
              Positioned(
                right: -2,
                top: 0,
                bottom: 0,
                width: artworkWidth,
                child: Image.asset(
                  '${paymentArt}secure_payment_card.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                20,
                showArtwork ? artworkWidth : 18,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: compact ? 25 : 28,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: paymentInk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PaymentSelectedMethod extends StatelessWidget {
  const PaymentSelectedMethod({
    super.key,
    required this.method,
    this.showRadio = true,
    this.subtitle,
  });
  final String method;
  final bool showRadio;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E5EF)),
    ),
    child: Row(
      children: [
        if (showRadio) ...[
          const Icon(
            Icons.radio_button_checked,
            color: CustomerColors.action,
            size: 21,
          ),
          const SizedBox(width: 12),
        ],
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: CustomerColors.selection,
            borderRadius: BorderRadius.circular(12),
          ),
          child: method == 'WALLET'
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
                method == 'WALLET'
                    ? 'BThere Wallet'
                    : method == 'CARD'
                    ? 'Credit / Debit Card'
                    : method,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: paymentInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle ??
                    (method == 'WALLET'
                        ? 'Your selected wallet'
                        : 'Your selected payment method'),
                style: const TextStyle(
                  fontSize: 11,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 400 &&
            MediaQuery.textScalerOf(context).scale(12) < 16) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: CustomerColors.action,
          ),
        ],
      ],
    ),
  );
}

class PaymentStatusNotice extends StatelessWidget {
  const PaymentStatusNotice({
    super.key,
    required this.title,
    required this.message,
    this.pending = false,
  });
  final String title, message;
  final bool pending;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFECF9F8),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          pending ? Icons.schedule_rounded : Icons.verified_rounded,
          size: 30,
          color: pending ? CustomerColors.action : const Color(0xFF2FA96D),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: paymentInk,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
