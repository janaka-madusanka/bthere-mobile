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
                          onPressed: busy ? null : () => _decide(false),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFFF5A67),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_double_arrow_left,
                          color: Color(0xFFFF8B96),
                        ),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF96EAE7),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x5544DAD5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: busy
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
                        const Icon(
                          Icons.keyboard_double_arrow_right,
                          color: Color(0xFF17CECA),
                        ),
                        IconButton(
                          tooltip: 'Accept request',
                          onPressed: busy ? null : () => _decide(true),
                          icon: const Icon(
                            Icons.check,
                            color: Color(0xFF00A5AE),
                          ),
                        ),
                      ],
                    ),
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
                        'Accept',
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

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.jobId});
  final int jobId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingControllerProvider).asData?.value;
    final booking = state?.bookings.where((b) => b.id == jobId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('Booking #$jobId')),
      body: booking == null
          ? const Center(child: Text('Booking details are unavailable.'))
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(bookingControllerProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    booking.statusLabel,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    booking.earningsLabel,
                    style: const TextStyle(fontSize: 20, color: bookingTeal),
                  ),
                  const Text(
                    'Expected earnings are credited after customer-confirmed completion.',
                  ),
                  if (booking.start != null)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(booking.start!.replaceFirst('T', ' ')),
                    ),
                  if (booking.address != null)
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(booking.address!),
                    ),
                  if (booking.answers != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Customer details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(booking.answers.toString()),
                  ],
                  if (state?.error != null)
                    Text(
                      state!.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (booking.canStart)
                    FilledButton(
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
                      child: const Text('Enter customer start code'),
                    ),
                  if (booking.canComplete)
                    FilledButton(
                      onPressed: state?.busy == true
                          ? null
                          : () => ref
                                .read(bookingControllerProvider.notifier)
                                .complete(booking),
                      child: const Text('Request completion'),
                    ),
                ],
              ),
            ),
    );
  }

  Future<String?> _code(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer start code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Six-digit code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
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
