import 'booking_provider_accepted.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import 'booking_payment_result_screen.dart';

class BookingRequestProgressScreen extends StatefulWidget {
  const BookingRequestProgressScreen({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onDetails,
  });
  final CustomerBookingController controller;
  final VoidCallback? onCancel;
  final VoidCallback onDetails;
  @override
  State<BookingRequestProgressScreen> createState() =>
      _BookingRequestProgressScreenState();
}

class _BookingRequestProgressScreenState
    extends State<BookingRequestProgressScreen> {
  Timer? _timer;
  int _ticks = 0;
  CustomerBookingController get c => widget.controller;
  bool get _matching => c.created?['status'] == 'MATCHING';
  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _changed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !c.alive) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      // Do not start a status read underneath the cancellation confirmation;
      // otherwise its busy state can swallow the user's confirm action.
      if (ModalRoute.of(context)?.isCurrent == false) return;
      if (++_ticks % 5 == 0 && !c.busy) {
        c.refreshCreatedRequest(background: true);
      }
      if (!_matching) setState(() {});
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    c.removeListener(_changed);
    super.dispose();
  }

  ProviderCandidate? get _provider {
    final id = c.created?['providerId'];
    return [
      ...c.candidates,
      ...c.availableCandidates,
      ...c.selected.values,
    ].where((p) => p.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final expiry = DateTime.tryParse('${c.created?['confirmationExpiresAt']}');
    final remaining = expiry?.difference(c.now()).inSeconds;
    final amount = c.created?['expectedAmount'];
    final currency = c.created?['currencyCode'];
    final confirmPayment =
        {'WALLET', 'CARD'}.contains(c.created?['paymentMethod']) &&
        amount is num &&
        amount.isFinite &&
        currency is String;
    return BookingRequestProgressView(
      paymentMethod: '${c.created?['paymentMethod']}',
      paymentAmount: confirmPayment
          ? walletMoney(amount)
                .replaceFirst('Rs.', currency == 'LKR' ? 'Rs.' : currency)
          : null,
      requestId: c.created?['requestId'] as int?,
      matching: _matching,
      serviceName: c.context!.name,
      provider: _provider,
      busy: c.busy,
      error: c.error,
      confirmationSeconds: remaining == null ? null : math.max(0, remaining),
      onCancel: widget.onCancel,
      onDetails: widget.onDetails,
    );
  }
}

/// Provider matching and acceptance presentation for the booking journey.
/// Status reads and countdown ownership stay with the caller.
class BookingRequestProgressView extends StatefulWidget {
  const BookingRequestProgressView({
    super.key,
    required this.matching,
    required this.serviceName,
    required this.onCancel,
    required this.onDetails,
    this.provider,
    this.confirmationSeconds,
    this.busy = false,
    this.error,
    this.animate = true,
    this.requestId,
    this.paymentAmount,
    this.paymentMethod = 'WALLET',
  });
  final bool matching, busy, animate;
  final String serviceName;
  final int? requestId;
  final String? paymentAmount;
  final String paymentMethod;
  final ProviderCandidate? provider;
  final int? confirmationSeconds;
  final String? error;
  final VoidCallback? onCancel;
  final VoidCallback onDetails;

  @override
  State<BookingRequestProgressView> createState() =>
      _BookingRequestProgressViewState();
}

class _BookingRequestProgressViewState extends State<BookingRequestProgressView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool get _matching => widget.matching;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant BookingRequestProgressView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_matching &&
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final seconds = widget.confirmationSeconds;
    final deadline = seconds == null
        ? null
        : '${'${seconds ~/ 60}'.padLeft(2, '0')}:${'${seconds % 60}'.padLeft(2, '0')}';
    return PopScope(
      canPop: !widget.busy,
      child: Scaffold(
        key: ValueKey(
          _matching ? 'booking-finding-provider' : 'booking-provider-accepted',
        ),
        backgroundColor: const Color(0xFFF5FDFE),
        body: BookingFlowBackdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, bounds.maxHeight - 48),
                    minWidth: math.max(0, bounds.maxWidth - 48),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_matching) ...[
                        SizedBox(
                          width: math.min(340, bounds.maxWidth - 48),
                          height: math.min(340, bounds.maxWidth - 48),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (final size in [1.0, .78, .57])
                                FractionallySizedBox(
                                  widthFactor: size,
                                  heightFactor: size,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF17B9BA)
                                          .withValues(alpha: .045),
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (_, _) => Transform.rotate(
                                    angle: _pulse.value * math.pi * 2,
                                    child: const CircularProgressIndicator(
                                      value: .20,
                                      strokeWidth: 3,
                                      color: CustomerColors.action,
                                    ),
                                  ),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: .65,
                                heightFactor: .65,
                                child: Image.asset(
                                  'assets/illustrations/booking/finding_provider.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              for (final offset in [
                                const Alignment(0, -1),
                                const Alignment(-.95, -.2),
                                const Alignment(.95, .25),
                                const Alignment(-.6, .85),
                              ])
                                Align(
                                  alignment: offset,
                                  child: const CircleAvatar(
                                    radius: 23,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person_outline,
                                      color: CustomerColors.action,
                                      size: 28,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Finding a suitable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFF8586A5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Provider for you',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1248),
                          ),
                        ),
                        if (widget.requestId != null &&
                            widget.requestId! > 0) ...[
                          const SizedBox(height: 10),
                          SelectableText(
                            'Request #${widget.requestId}',
                            key: const ValueKey('booking-matching-request-id'),
                            style: const TextStyle(
                              color: CustomerColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          'We’re searching for available providers for ${widget.serviceName}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF8586A5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Payment is pending provider acceptance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: CustomerColors.secondaryText,
                          ),
                        ),
                      ] else ...[
                        BookingProviderAccepted(
                          error: widget.error,
                          paymentMethod: widget.paymentMethod,
                          paymentAmount: widget.paymentAmount,
                          serviceName: widget.serviceName,
                          provider: provider,
                          deadline: deadline,
                          expired: seconds == 0,
                          busy: widget.busy,
                          availableHeight: bounds.maxHeight,
                          onContinue: widget.onDetails,
                          onCancel: widget.onCancel,
                        ),
                      ],
                      if (_matching && widget.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            widget.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CustomerColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (_matching && widget.onCancel != null)
                        TextButton.icon(
                          key: const ValueKey('booking-cancel-request'),
                          onPressed: widget.busy ? null : widget.onCancel,
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Color(0xFFF46572),
                          ),
                          label: const Text(
                            'Cancel request',
                            style: TextStyle(color: Color(0xFFF46572)),
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
    );
  }
}
