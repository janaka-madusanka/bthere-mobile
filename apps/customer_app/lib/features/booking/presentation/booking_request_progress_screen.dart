import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
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
    extends State<BookingRequestProgressScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _timer;
  int _ticks = 0;
  CustomerBookingController get c => widget.controller;
  bool get _matching => c.created?['status'] == 'MATCHING';
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    c.addListener(_changed);
    _changed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !c.alive) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      if (++_ticks % 5 == 0 && !c.busy) c.refreshCreatedRequest();
      if (!_matching) setState(() {});
    });
  }

  void _changed() {
    if (_matching && !_pulse.isAnimating) _pulse.repeat();
    if (!_matching && _pulse.isAnimating) _pulse.stop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    c.removeListener(_changed);
    _pulse.dispose();
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
    final provider = _provider;
    final expiry = DateTime.tryParse('${c.created?['confirmationExpiresAt']}');
    final remaining = expiry?.difference(c.now()).inSeconds;
    final seconds = remaining == null ? null : math.max(0, remaining);
    final deadline = seconds == null
        ? null
        : '${'${seconds ~/ 60}'.padLeft(2, '0')}:${'${seconds % 60}'.padLeft(2, '0')}';
    return PopScope(
      canPop: !c.busy,
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
                        const SizedBox(height: 14),
                        Text(
                          'We’re searching for available providers for ${c.context!.name}.',
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
                        const Text(
                          'We found a provider!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C1248),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A provider has accepted your request.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8586A5),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Image.asset(
                          'assets/illustrations/booking/provider_accepted.png',
                          height: math.min(220, bounds.maxHeight * .25),
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE0F3F4)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: provider?.photo == null
                                          ? const ColoredBox(
                                              color: CustomerColors.selection,
                                              child: Icon(
                                                Icons.person,
                                                color: CustomerColors.action,
                                                size: 36,
                                              ),
                                            )
                                          : Image.network(
                                              provider!.photo!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.person,
                                                    size: 36,
                                                    color:
                                                        CustomerColors.action,
                                                  ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          provider?.name ?? 'Your provider',
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0C1248),
                                          ),
                                        ),
                                        if (provider?.data['averageRating']
                                            is num)
                                          Text(
                                            '★ ${provider!.data['averageRating']} (${provider.data['totalRatings'] ?? 0} ratings)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  CustomerColors.secondaryText,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CustomerColors.selection,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Confirm payment before',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0C1248),
                                      ),
                                    ),
                                    if (deadline != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          deadline,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            color: CustomerColors.action,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      seconds == 0
                                          ? 'Confirmation time has expired. Refresh the request status.'
                                          : 'Payment requires your confirmation. You will not be automatically charged.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: CustomerColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: c.busy ? null : widget.onDetails,
                                child: const Text('Continue to payment'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (c.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            c.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CustomerColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: c.busy ? null : widget.onDetails,
                        child: const Text('View request details'),
                      ),
                      if (widget.onCancel != null)
                        TextButton.icon(
                          onPressed: c.busy ? null : widget.onCancel,
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
