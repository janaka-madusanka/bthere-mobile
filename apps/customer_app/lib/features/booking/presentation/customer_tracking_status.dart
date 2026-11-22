import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_tracking_status_controller.dart';
import '../../../app/customer_providers.dart';
import 'customer_live_tracking_map.dart';
import 'tracking_provider_details.dart';
import 'booking_navigation_link.dart';
import 'booking_details_reference.dart';

class CustomerTrackingStatus extends ConsumerStatefulWidget {
  const CustomerTrackingStatus({
    super.key,
    required this.jobId,
    this.team = false,
    this.compact = false,
    this.booking,
  });
  final int jobId;
  final bool team;
  final bool compact;
  final Map<String, dynamic>? booking;
  @override
  ConsumerState<CustomerTrackingStatus> createState() =>
      _CustomerTrackingStatusState();
}

class _CustomerTrackingStatusState extends ConsumerState<CustomerTrackingStatus>
    with WidgetsBindingObserver {
  late final CustomerTrackingStatusController c;
  Timer? timer;
  Timer? staleTimer;
  bool get foreground =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c = CustomerTrackingStatusController(
      ref.read(customerBookingRepositoryProvider),
      ref.read(customerAuthControllerProvider),
      widget.jobId,
    );
    c.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (foreground) refresh();
    });
  }

  void changed() {
    scheduleStaleness();
    if (mounted) setState(() {});
  }

  void scheduleStaleness() {
    staleTimer?.cancel();
    if (!foreground || c.status == null) return;
    final now = ref.read(customerClockProvider)().toUtc();
    final deadlines =
        c.status!.providers
            .where((p) => !p.stale(now, c.status!.staleSeconds))
            .map(
              (p) =>
                  p.recordedAt!.add(Duration(seconds: c.status!.staleSeconds)),
            )
            .where((d) => d.isAfter(now))
            .toList()
          ..sort();
    if (deadlines.isNotEmpty) {
      staleTimer = Timer(deadlines.first.difference(now), () {
        if (mounted && foreground) {
          setState(() {});
          scheduleStaleness();
        }
      });
    }
  }

  Future<void> refresh() async {
    timer?.cancel();
    staleTimer?.cancel();
    if (!foreground || !c.alive) return;
    await c.refresh();
    scheduleStaleness();
    schedule();
  }

  void schedule() {
    timer?.cancel();
    if (!mounted || !c.polls) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    timer = Timer(Duration(seconds: c.status!.pollSeconds), () {
      if (foreground) {
        refresh();
      } else {
        schedule();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    staleTimer?.cancel();
    if (state == AppLifecycleState.resumed && foreground) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    staleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!c.alive || c.status?.status == 'NOT_SUPPORTED' && !widget.compact) {
      return const SizedBox.shrink();
    }
    if (widget.compact) {
      final status = c.status;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status?.showsMap == true)
            CustomerLiveTrackingMap(tracking: status!, compact: true)
          else
            BookingLocationPreview(
              point:
                  status?.target ?? bookingLocationPoint(widget.booking ?? {}),
              label: widget.booking?['meetingPointName'] as String?,
            ),
          if (status != null && status.status != 'NOT_SUPPORTED')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                switch (status.status) {
                  'NOT_STARTED' => 'Scheduled',
                  'ENDED' => 'Tracking ended',
                  'WAITING_FOR_CONFIRMATION' => 'Awaiting payment confirmation',
                  'EN_ROUTE' => 'Provider on the way',
                  'ARRIVED' => 'Provider has arrived',
                  _ => 'Trip in progress',
                },
                style: CustomerTypography.compactStrong.copyWith(
                  color: CustomerColors.action,
                ),
              ),
            ),
          if (c.error != null)
            TextButton(
              onPressed: refresh,
              child: const Text('Check tracking status'),
            ),
        ],
      );
    }
    final (title, message, icon) = switch (c.status?.status) {
      'WAITING_FOR_CONFIRMATION' => (
        'Awaiting payment confirmation',
        'Tracking will become available after confirmation.',
        Icons.lock_clock_outlined,
      ),
      'NOT_STARTED' => (
        'Scheduled',
        'Your provider has not started the journey yet.',
        Icons.schedule_rounded,
      ),
      'EN_ROUTE' => (
        'Provider on the way',
        'Your provider is travelling to the pickup or service location.',
        Icons.near_me_outlined,
      ),
      'ARRIVED' => (
        'Provider has arrived',
        'Your provider has marked arrival at the pickup or service location.',
        Icons.place_outlined,
      ),
      'IN_TRIP' => (
        'Trip in progress',
        'The journey to your destination is in progress.',
        Icons.directions_car_outlined,
      ),
      'ENDED' => (
        'Tracking ended',
        'There are no more live journey updates for this booking.',
        Icons.check_circle_outline,
      ),
      _ => (
        'Provider journey',
        c.error == null
            ? 'Checking the latest journey status…'
            : 'Journey updates are currently unavailable.',
        Icons.route_outlined,
      ),
    };
    return Container(
      key: const ValueKey('booking-tracking-status'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerColors.selection,
        border: Border.all(color: CustomerColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: CustomerColors.action),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: CustomerTypography.card)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: CustomerTypography.compact),
          if (widget.team)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Individual providers may be at different stages. This shows the furthest journey stage.',
                style: CustomerTypography.compact,
              ),
            ),
          if (c.status?.showsMap == true)
            CustomerLiveTrackingMap(tracking: c.status!),
          if (c.status?.showsMap == true && c.status!.navigation != null)
            BookingNavigationLink(uri: c.status!.navigation!),
          if (c.status != null && c.status!.status != 'ENDED')
            TrackingProviderDetails(
              tracking: c.status!,
              now: ref.read(customerClockProvider)(),
              readFailed: c.error != null,
            ),
          if (c.error != null) ...[
            const SizedBox(height: 8),
            Text(
              c.error!,
              style: CustomerTypography.compact.copyWith(
                color: CustomerColors.error,
              ),
            ),
            TextButton(
              onPressed: c.reading ? null : refresh,
              child: const Text('Check tracking status'),
            ),
          ] else if (c.status == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
