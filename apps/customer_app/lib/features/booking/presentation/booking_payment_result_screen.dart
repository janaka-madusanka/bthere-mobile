import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

class BookingPaymentResultScreen extends StatelessWidget {
  const BookingPaymentResultScreen({
    super.key,
    required this.success,
    required this.subtitle,
    required this.onHome,
    required this.onBooking,
    this.onRetry,
    this.onDifferentMethod,
    this.reason,
    this.busy = false,
    this.testPayment = false,
  });
  final bool success, busy, testPayment;
  final String subtitle;
  final String? reason;
  final VoidCallback onHome, onBooking;
  final VoidCallback? onRetry, onDifferentMethod;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey(
      success ? 'booking-payment-success' : 'booking-payment-failed',
    ),
    backgroundColor: const Color(0xFFF5FDFE),
    body: CustomPaint(
      painter: const _PaymentBackground(),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, bounds.maxHeight - 48),
                minWidth: math.max(0, bounds.maxWidth - 48),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: success ? 32 : 4),
                  if (success)
                    Image.asset(
                      'assets/illustrations/payment/payment_success.png',
                      height: math.min(bounds.maxHeight * .38, 300),
                      fit: BoxFit.contain,
                      semanticLabel: 'Happy bee holding a success symbol',
                    )
                  else
                    Image.asset(
                      'assets/illustrations/payment/payment_failed.png',
                      height: math.min(bounds.maxHeight * .30, 250),
                      fit: BoxFit.contain,
                      semanticLabel: 'Bee holding a payment failed symbol',
                    ),
                  const SizedBox(height: 20),
                  Text(
                    success ? 'Payment Successful!' : 'Payment Failed!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C1248),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFF797C9C),
                    ),
                  ),
                  if (testPayment)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Test payment · no real card charge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                    ),
                  if (!success) ...[
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFDDF2F3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0C1248),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 19,
                                backgroundColor: Color(0xFFFFEEEE),
                                child: Icon(
                                  Icons.credit_card_off_outlined,
                                  color: Color(0xFFF46572),
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason ??
                                      'The payment could not be completed.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: CustomerColors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('payment-result-retry'),
                        onPressed: busy ? null : onRetry,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('payment-result-change-method'),
                        onPressed: busy ? null : onDifferentMethod,
                        icon: const Icon(Icons.credit_card),
                        label: const Text('Use Different Payment Method'),
                      ),
                    ),
                    if (onDifferentMethod == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'This booking’s payment method cannot be changed here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 30),
                    OutlinedButton(
                      onPressed: busy ? null : onBooking,
                      child: const Text('View booking'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextButton(
                    key: const ValueKey('payment-result-home'),
                    onPressed: busy ? null : onHome,
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaymentBackground extends CustomPainter {
  const _PaymentBackground();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE6F9FA);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .28,
        size.height * .08,
        size.width * .52,
        size.height * .22,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .82,
        size.height * .04,
        size.width * .50,
        size.height * .18,
      ),
      paint,
    );
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.83 + i * .04);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .35,
          y - 80,
          size.width * .5,
          y + 90,
          size.width,
          y - 20,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xFFE8FAFB),
            const Color(0xFFDDF7F8),
            const Color(0xFFCEF1F3),
          ][i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BookingFlowBackdrop extends StatelessWidget {
  const BookingFlowBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: CustomPaint(painter: const _PaymentBackground(), child: child),
  );
}
