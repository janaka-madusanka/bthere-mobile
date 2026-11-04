import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import 'booking_payment_visuals.dart';

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
    this.selectedMethod,
    this.selectedCardLabel,
    this.busy = false,
    this.testPayment = false,
    this.onAutoContinue,
    this.autoContinueDelay = const Duration(seconds: 3),
  });
  final bool success, busy, testPayment;
  final String subtitle;
  final String? reason;
  final String? selectedMethod, selectedCardLabel;
  final VoidCallback onHome, onBooking;
  final VoidCallback? onRetry, onDifferentMethod;
  final VoidCallback? onAutoContinue;
  final Duration autoContinueDelay;

  @override
  Widget build(BuildContext context) => success
      ? _PaymentSuccessRedirect(
          subtitle: subtitle,
          busy: busy,
          testPayment: testPayment,
          onBooking: onBooking,
          onHome: onHome,
          onAutoContinue: onAutoContinue,
          delay: autoContinueDelay,
        )
      : _PaymentFailureView(
          subtitle: subtitle,
          reason: reason,
          selectedMethod: selectedMethod,
          selectedCardLabel: selectedCardLabel,
          busy: busy,
          testPayment: testPayment,
          onRetry: onRetry,
          onDifferentMethod: onDifferentMethod,
          onHome: onHome,
        );
}

class _PaymentSuccessRedirect extends StatefulWidget {
  const _PaymentSuccessRedirect({
    required this.subtitle,
    required this.busy,
    required this.testPayment,
    required this.onBooking,
    required this.onHome,
    required this.onAutoContinue,
    required this.delay,
  });
  final String subtitle;
  final bool busy, testPayment;
  final VoidCallback onBooking, onHome;
  final VoidCallback? onAutoContinue;
  final Duration delay;
  @override
  State<_PaymentSuccessRedirect> createState() =>
      _PaymentSuccessRedirectState();
}

class _PaymentSuccessRedirectState extends State<_PaymentSuccessRedirect>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_finished || widget.busy || widget.onAutoContinue == null) return;
    _timer = Timer(widget.delay, () {
      if (!mounted ||
          widget.busy ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      _open(widget.onAutoContinue!);
    });
  }

  void _open(VoidCallback action) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    action();
  }

  @override
  void didUpdateWidget(covariant _PaymentSuccessRedirect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        oldWidget.delay != widget.delay ||
        (oldWidget.onAutoContinue == null) != (widget.onAutoContinue == null)) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PaymentSuccessView(
    subtitle: widget.subtitle,
    busy: widget.busy,
    testPayment: widget.testPayment,
    onBooking: () => _open(widget.onBooking),
    onHome: () => _open(widget.onHome),
    autoContinue: widget.onAutoContinue != null,
  );
}

class _PaymentFailureView extends StatelessWidget {
  const _PaymentFailureView({
    required this.subtitle,
    required this.reason,
    required this.selectedMethod,
    this.selectedCardLabel,
    required this.busy,
    required this.testPayment,
    required this.onRetry,
    required this.onDifferentMethod,
    required this.onHome,
  });
  final String subtitle;
  final String? reason;
  final String? selectedMethod, selectedCardLabel;
  final bool busy, testPayment;
  final VoidCallback? onRetry, onDifferentMethod;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('booking-payment-failed'),
    backgroundColor: const Color(0xFFF5FDFE),
    body: BookingFlowBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, bounds.maxHeight - 48),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/illustrations/payment/payment_failed.png',
                        height: math.min(290, bounds.maxHeight * .33),
                        fit: BoxFit.contain,
                        semanticLabel: 'Bee holding a payment failed symbol',
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Payment Failed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0C1248),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _FailureReasons(reason: reason),
                      if (selectedMethod != null) ...[
                        const SizedBox(height: 18),
                        Column(
                          key: const ValueKey('payment-replacement-selection'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Selected payment method',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0C1248),
                              ),
                            ),
                            const SizedBox(height: 10),
                            PaymentSelectedMethod(
                              method: selectedMethod!,
                              subtitle: selectedCardLabel,
                              showRadio: false,
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Try Again will send a new provider request.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: CustomerColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (testPayment) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Test payment \u00b7 no real card charge',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        key: const ValueKey('payment-result-retry'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy ? null : onRetry,
                        icon: busy
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(
                          busy ? 'Trying again...' : 'Try Again',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const ValueKey('payment-result-change-method'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: CustomerColors.action),
                          backgroundColor: Colors.white.withValues(alpha: .7),
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy ? null : onDifferentMethod,
                        icon: const Icon(Icons.credit_card_rounded, size: 20),
                        label: const Text(
                          'Use Different Payment Method',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onDifferentMethod == null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'This booking?s payment method cannot be changed here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        key: const ValueKey('payment-result-home'),
                        onPressed: busy ? null : onHome,
                        child: const Text(
                          'Go to Home',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FailureReasons extends StatelessWidget {
  const _FailureReasons({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final detail = reason?.trim();
    final known = detail != null && detail.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDFF1F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06008085),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            known ? 'Payment details' : 'Possible Reasons',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C1248),
            ),
          ),
          const SizedBox(height: 14),
          _FailureReasonRow(
            icon: Icons.credit_card_rounded,
            text: known ? detail : 'Insufficient balance',
          ),
          if (!known) ...[
            const SizedBox(height: 12),
            const _FailureReasonRow(
              icon: Icons.lock_outline_rounded,
              text: 'Your bank may have declined the transaction',
            ),
          ],
        ],
      ),
    );
  }
}

class _FailureReasonRow extends StatelessWidget {
  const _FailureReasonRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEEEE),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 24, color: Color(0xFFF25C6A)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: CustomerColors.secondaryText,
          ),
        ),
      ),
    ],
  );
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView({
    required this.subtitle,
    required this.busy,
    required this.testPayment,
    required this.onBooking,
    required this.onHome,
    this.autoContinue = false,
  });
  final String subtitle;
  final bool busy, testPayment;
  final bool autoContinue;
  final VoidCallback onBooking, onHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('booking-payment-success'),
    backgroundColor: const Color(0xFFF5FDFE),
    body: BookingFlowBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, bounds.maxHeight - 48),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/illustrations/payment/payment_success.png',
                        height: math.min(290, bounds.maxHeight * .34),
                        fit: BoxFit.contain,
                        semanticLabel: 'Happy bee holding a success symbol',
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Payment Successful!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0C1248),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                      if (autoContinue) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Your booking details will open shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: CustomerColors.selection,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: CustomerColors.action,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment confirmed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0C1248),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'View your booking for the latest details.',
                                        style: TextStyle(
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
                            if (testPayment) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7E8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Test payment · no real card charge',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: Color(0xFF87652B),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              key: const ValueKey('payment-result-booking'),
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
                              onPressed: busy ? null : onBooking,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'View booking',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded, size: 19),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              key: const ValueKey('payment-result-home'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: busy ? null : onHome,
                              child: const Text(
                                'Go to Home',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
