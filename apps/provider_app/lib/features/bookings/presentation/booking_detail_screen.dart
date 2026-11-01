import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bthere_common/bthere_common.dart';

import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_type.dart';

import '../../../app/providers/app_providers.dart';
import '../application/booking_controller.dart';
import '../application/booking_alert.dart';
import '../domain/booking_models.dart';
import 'booking_scaffold.dart';
import 'booking_payment_window.dart';

Future<void> showBookingOffer(BuildContext context, BookingOffer offer) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomingBookingDialog(offer: offer),
    );

class IncomingBookingDialog extends ConsumerStatefulWidget {
  const IncomingBookingDialog({super.key, required this.offer});
  final BookingOffer offer;
  @override
  ConsumerState<IncomingBookingDialog> createState() =>
      _IncomingBookingDialogState();
}

class _IncomingBookingDialogState extends ConsumerState<IncomingBookingDialog> {
  Timer? timer;
  int seconds = 0;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    _tick();
    if (!closing) BookingAlert.start();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || closing) return;
    final remaining = widget.offer.expiresAt
        .difference(ref.read(clockProvider)())
        .inSeconds;
    if (remaining <= 0) {
      BookingAlert.stop();
      closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() => seconds = remaining);
    }
  }

  @override
  void dispose() {
    BookingAlert.stop();
    timer?.cancel();
    super.dispose();
  }

  Future<void> _decide(bool accept) async {
    await BookingAlert.stop();
    final success = await ref
        .read(bookingControllerProvider.notifier)
        .decide(widget.offer, accept: accept);
    if (mounted && success && !closing) {
      closing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bookingControllerProvider, (_, next) {
      final data = next.asData?.value;
      if (data != null &&
          !data.busy &&
          !data.offers.any((o) => o.id == widget.offer.id) &&
          !closing) {
        closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
    final busy =
        ref.watch(bookingControllerProvider).asData?.value.busy ?? false;
    final catalog = ref.watch(providerServiceCatalogProvider).asData?.value;
    final title = catalog is Success<List<ProviderServiceType>>
        ? catalog.value
              .where((s) => s.id == widget.offer.serviceTypeId)
              .firstOrNull
              ?.name
        : null;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const RadialGradient(
              radius: .8,
              colors: [Color(0xFFE7FBFA), Colors.white],
            ),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 14,
              color: bookingInk,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 35,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0DAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF2FDFD),
                      border: Border.all(
                        color: const Color(0xFFDAF7F7),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3059E3DB),
                          blurRadius: 40,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      size: 39,
                      color: Color(0xFF00A1AC),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NEW SERVICE REQUEST',
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      letterSpacing: 2,
                      fontSize: 10,
                      color: bookingMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title ?? 'Service request',
                    style: const TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: bookingInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A client near you needs assistance',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: bookingMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.offer.earningsLabel,
                    style: const TextStyle(
                      color: bookingTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        Icons.schedule,
                        widget.offer.start?.replaceFirst('T', ' ') ??
                            'Scheduled service',
                      ),
                      _chip(Icons.timer_outlined, '${seconds}s remaining'),
                      if (widget.offer.address != null)
                        _chip(
                          Icons.location_on_outlined,
                          widget.offer.address!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  IncomingOfferSlider(
                    busy: busy,
                    onAccept: () => _decide(true),
                    onDecline: () => _decide(false),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Decline',
                        style: TextStyle(
                          color: Color(0xFFFF5A67),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Slide to accept',
                        style: TextStyle(color: bookingTeal, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F8F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: bookingTeal, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: bookingInk),
          ),
        ),
      ],
    ),
  );
}

/// Accepting requires dragging the center handle to the right end.
class IncomingOfferSlider extends StatefulWidget {
  const IncomingOfferSlider({
    super.key,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final bool busy;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<IncomingOfferSlider> createState() => _IncomingOfferSliderState();
}

class _IncomingOfferSliderState extends State<IncomingOfferSlider> {
  double progress = 0;
  bool submitting = false;
  bool dragging = false;

  bool get disabled => widget.busy || submitting;

  Future<void> _accept() async {
    setState(() => submitting = true);
    try {
      await widget.onAccept();
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
          progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const handleSize = 70.0;
      final travel = (constraints.maxWidth - handleSize) / 2;
      return SizedBox(
        height: handleSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD1D6), Color(0xFF7CE9E3)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Decline request',
                    onPressed: disabled ? null : () => widget.onDecline(),
                    icon: const Icon(Icons.close, color: Color(0xFFFF5A67)),
                  ),
                  const Icon(
                    Icons.keyboard_double_arrow_left,
                    color: Color(0xFFFF8B96),
                  ),
                  const SizedBox(width: handleSize),
                  const Icon(
                    Icons.keyboard_double_arrow_right,
                    color: Color(0xFF17CECA),
                  ),
                  const SizedBox(
                    width: 48,
                    child: Icon(Icons.check, color: Color(0xFF00A5AE)),
                  ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: travel + progress * travel,
              child: Semantics(
                label: 'Slide to accept request',
                hint: 'Drag right to the check mark',
                child: GestureDetector(
                  key: const ValueKey('incoming-offer-handle'),
                  onHorizontalDragStart: disabled
                      ? null
                      : (_) {
                          setState(() => dragging = true);
                        },
                  onHorizontalDragUpdate: disabled
                      ? null
                      : (details) {
                          if (travel <= 0) return;
                          setState(() {
                            progress = (progress + details.delta.dx / travel)
                                .clamp(0.0, 1.0);
                          });
                        },
                  onHorizontalDragCancel: () => setState(() {
                    dragging = false;
                    progress = 0;
                  }),
                  onHorizontalDragEnd: disabled
                      ? null
                      : (_) {
                          setState(() => dragging = false);
                          if (progress >= .9) {
                            _accept();
                          } else {
                            setState(() => progress = 0);
                          }
                        },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF96EAE7),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x5544DAD5), blurRadius: 20),
                      ],
                    ),
                    child: disabled
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(),
                          )
                        : Center(
                            child: SvgPicture.asset(
                              'assets/opportunities/incoming_imgGroup.svg',
                              width: 30.97,
                              height: 38,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.jobId});
  final int jobId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingControllerProvider).asData?.value;
    final booking = state?.bookings.where((b) => b.id == jobId).firstOrNull;
    final requestId =
        booking?.requestId ??
        ref.read(bookingControllerProvider.notifier).requestIdFor(jobId);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8F8),
        title: Text('Booking #$jobId'),
      ),
      body: booking == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    size: 48,
                    color: bookingTeal,
                  ),
                  const SizedBox(height: 16),
                  const Text('Booking details are unavailable.'),
                  TextButton(
                    onPressed: () =>
                        ref.read(bookingControllerProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(bookingControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              booking.status == 'CANCELLED'
                                  ? Icons.cancel_outlined
                                  : Icons.event_available_outlined,
                              color: booking.status == 'CANCELLED'
                                  ? const Color(0xFFB34F50)
                                  : bookingTeal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                booking.statusLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: bookingInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          booking.status == 'CANCELLED' ||
                                  booking.status == 'EXPIRED'
                              ? 'Booking cancelled'
                              : booking.completed
                              ? 'Service completed'
                              : 'Your service booking',
                          style: const TextStyle(color: bookingMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          booking.status == 'CANCELLED' ||
                                  booking.status == 'EXPIRED'
                              ? 'No earnings for this booking'
                              : booking.earningsLabel,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: bookingTeal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          booking.status == 'CANCELLED' ||
                                  booking.status == 'EXPIRED'
                              ? 'This service will not go ahead.'
                              : 'Expected earnings are credited after customer-confirmed completion.',
                          style: const TextStyle(
                            color: bookingMuted,
                            height: 1.5,
                          ),
                        ),
                        const Divider(height: 32),
                        _info(
                          Icons.payments_outlined,
                          'Payment',
                          _label(booking.paymentStatus),
                        ),
                        if (booking.details['paymentFundingMode'] == 'MOCK')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Test payment - No real card charged',
                              style: TextStyle(color: bookingMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Service details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _info(
                          Icons.schedule,
                          'Scheduled start',
                          booking.start == null
                              ? 'Not provided'
                              : _date(booking.start!),
                        ),
                        const SizedBox(height: 16),
                        _info(
                          Icons.location_on_outlined,
                          'Service location',
                          booking.address ?? 'Location not provided',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._answers(booking.answers),
                      ],
                    ),
                  ),
                  if (requestId != null &&
                      [
                        'AWAITING_PAYMENT',
                        'AWAITING_CUSTOMER_CONFIRMATION',
                      ].contains(booking.status)) ...[
                    const SizedBox(height: 16),
                    BookingPaymentWindowCard(
                      requestId: requestId,
                      serviceStart: booking.start,
                    ),
                  ],
                  if (requestId == null &&
                      [
                        'AWAITING_PAYMENT',
                        'AWAITING_CUSTOMER_CONFIRMATION',
                      ].contains(booking.status)) ...[
                    const SizedBox(height: 16),
                    _card(
                      const Text(
                        'Payment controls are unavailable for this booking. Contact support if you need to change its payment deadline.',
                      ),
                    ),
                  ],
                  if (state?.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        state!.error!,
                        style: const TextStyle(color: Color(0xFFB34F50)),
                      ),
                    ),
                  if (booking.canStart)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: state?.busy == true
                            ? null
                            : () async {
                                final code = await _code(context);
                                if (code != null) {
                                  await ref
                                      .read(bookingControllerProvider.notifier)
                                      .start(booking, code);
                                }
                              },
                        label: const Text('Enter customer start code'),
                      ),
                    ),
                  if (booking.canComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: FilledButton(
                        onPressed: state?.busy == true
                            ? null
                            : () => ref
                                  .read(bookingControllerProvider.notifier)
                                  .complete(booking),
                        child: const Text('Request completion'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE1EEEE)),
    ),
    child: child,
  );

  static String _label(String value) => value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
  static String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _info(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: bookingTeal, size: 21),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: bookingMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: bookingInk, height: 1.4)),
          ],
        ),
      ),
    ],
  );

  List<Widget> _answers(Object? answers) {
    final entries = <MapEntry<String, Object?>>[];
    if (answers is Map) {
      entries.addAll(
        answers.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );
    } else if (answers is List) {
      for (final item in answers) {
        if (item is Map) {
          final label =
              item['label'] ??
              item['questionLabel'] ??
              item['questionCode'] ??
              item['fieldCode'] ??
              item['code'];
          final value = item['value'] ?? item['answer'];
          if (label != null && value != null) {
            entries.add(MapEntry(label.toString(), value));
          }
        }
      }
    }
    if (entries.isEmpty) {
      return [
        const Text(
          'No customer details provided.',
          style: TextStyle(color: bookingMuted),
        ),
      ];
    }
    String display(Object? value) => value is Map
        ? value.values.map(display).join(', ')
        : value is List
        ? value.map(display).join(', ')
        : value?.toString() ?? 'Not provided';
    return [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _info(
            Icons.person_outline,
            _label(entry.key.replaceFirst(RegExp(r'^CG_'), '')),
            display(entry.value),
          ),
        ),
    ];
  }

  Future<String?> _code(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer start code'),
        content: TextFormField(
          controller: controller,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => RegExp(r'^\d{4}$').hasMatch(value ?? '')
              ? null
              : 'Enter exactly four digits',
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Four-digit code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4}$').hasMatch(controller.text)) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Start service'),
          ),
        ],
      ),
    );
    // Keep the controller alive until the dialog's exit animation finishes.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return code;
  }
}
