import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/booking_controller.dart';
import 'booking_detail_screen.dart';

/// Foreground polling also recovers missed events after resume/restart.
class BookingOfferHost extends ConsumerStatefulWidget {
  const BookingOfferHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<BookingOfferHost> createState() => _BookingOfferHostState();
}

class _BookingOfferHostState extends ConsumerState<BookingOfferHost>
    with WidgetsBindingObserver {
  Timer? timer;
  bool showing = false;
  final shown = <int>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll();
  }

  void _poll() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final async = ref.read(bookingControllerProvider);
      if (async.hasError) {
        ref.invalidate(bookingControllerProvider);
      } else {
        ref.read(bookingControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(bookingControllerProvider.notifier).refresh();
      _poll();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingControllerProvider);
    final data = async.asData?.value;
    if (!showing && data != null && !data.busy) {
      final offer = data.offers.where((o) => !shown.contains(o.id)).firstOrNull;
      if (offer != null) {
        showing = true;
        shown.add(offer.id);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showBookingOffer(context, offer);
          if (mounted) setState(() => showing = false);
        });
      }
    }
    return widget.child;
  }
}
