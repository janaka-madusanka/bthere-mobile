import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/customer_providers.dart';
import '../../../app/customer_theme.dart';
import '../domain/booking_models.dart';
import 'customer_booking_map.dart';

class BookingDetailsIdentity extends StatelessWidget {
  const BookingDetailsIdentity({
    super.key,
    required this.name,
    required this.jobId,
    required this.status,
    this.start,
  });
  final String name, status;
  final Object? jobId;
  final DateTime? start;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final spacious =
          bounds.maxWidth >= 420 &&
          MediaQuery.textScalerOf(context).scale(14) <= 19;
      final statusLine = BookingStatusSummary(status: status, start: start);
      final inlineFailure =
          status == 'PAYMENT_FAILED' &&
          bounds.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 19;
      return Column(
        key: const ValueKey('booking-details-header'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const ValueKey('booking-service-name'),
                      style: CustomerTypography.screen.copyWith(
                        color: const Color(0xFF101D42),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      key: const ValueKey('booking-id-chip'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F3F9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Booking #$jobId',
                        style: CustomerTypography.compactStrong.copyWith(
                          color: const Color(0xFF68718B),
                        ),
                      ),
                    ),
                    if (spacious && !inlineFailure) ...[
                      const SizedBox(height: 12),
                      statusLine,
                    ],
                  ],
                ),
              ),
              if (inlineFailure) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bounds.maxWidth * .46),
                  child: statusLine,
                ),
              ],
            ],
          ),
          if (!spacious && !inlineFailure) ...[
            const SizedBox(height: 14),
            statusLine,
          ],
        ],
      );
    },
  );
}

String bookingReferenceSchedule(
  BuildContext context,
  Object? start,
  Object? end,
) {
  final a = DateTime.tryParse('$start'), b = DateTime.tryParse('$end');
  if (a == null) return 'Schedule not provided';
  final l = MaterialLocalizations.of(context);
  String date(DateTime d) => l.formatShortMonthDay(d);
  String time(DateTime d) => l.formatTimeOfDay(
    TimeOfDay.fromDateTime(d),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final first = '${date(a)} · ${time(a)}';
  if (b == null) return first;
  final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
  return '$first – ${sameDay ? time(b) : '${date(b)} · ${time(b)}'}';
}

class BookingDetailsHeaderBackground extends StatelessWidget {
  const BookingDetailsHeaderBackground({super.key});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00646A),
                  Color(0xFF00AAA9),
                  Color(0xFF00666B),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -80,
          top: -100,
          width: 250,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -55,
          bottom: -110,
          width: 230,
          height: 230,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

DateTime? bookingScheduledInstant(Map<String, dynamic> booking, String? zone) {
  for (final key in ['startDatetimeUtc', 'startAtUtc']) {
    final utc = booking[key];
    if (utc is String && RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(utc)) {
      final instant = DateTime.tryParse(utc);
      if (instant != null) return instant.toUtc();
    }
  }
  final raw =
      booking['startDatetime'] ??
      booking['requestedPickupTime'] ??
      booking['startAt'];
  if (raw is! String) return null;
  final value = DateTime.tryParse(raw);
  if (value == null) return null;
  if (RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw)) return value.toUtc();
  final marketZone = booking['marketTimezone'] as String? ?? zone;
  if (marketZone == null) return null;
  try {
    return tz.TZDateTime(
      MarketTime.location(marketZone),
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    ).toUtc();
  } catch (_) {
    return null;
  }
}

class BookingStatusSummary extends ConsumerStatefulWidget {
  const BookingStatusSummary({super.key, required this.status, this.start});
  final String status;
  final DateTime? start;
  @override
  ConsumerState<BookingStatusSummary> createState() => _StatusState();
}

class _StatusState extends ConsumerState<BookingStatusSummary>
    with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          widget.status == 'CONFIRMED' &&
          widget.start != null &&
          ModalRoute.of(context)?.isCurrent != false &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final failed = {
      'CANCELLED',
      'EXPIRED',
      'REJECTED',
      'PAYMENT_FAILED',
    }.contains(status);
    final label = switch (status) {
      'CONFIRMED' => 'Ready',
      'IN_PROGRESS' => 'In progress',
      'AWAITING_COMPLETION_CONFIRMATION' => 'Confirm completion',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      'EXPIRED' => 'Expired',
      'AWAITING_PAYMENT' => 'Awaiting payment',
      'PAYMENT_FAILED' => 'Payment failed',
      'REJECTED' => 'Declined',
      'NO_SHOW_REVIEW' => 'Under review',
      'PENDING' => 'Pending',
      _ => 'Status unavailable',
    };
    final difference = widget.start?.difference(
      ref.read(customerBookingClockProvider).now(),
    );
    // Recompute from the deadline; never decrement a stored counter, so resume
    // and delayed frames cannot make the countdown drift.
    final seconds = difference == null
        ? null
        : (difference.inMilliseconds / 1000).ceil();
    String digits(int value) => value.toString().padLeft(2, '0');
    final overdue = seconds != null && seconds <= 0;
    String durationText(int value) =>
        '${digits(value ~/ 3600)}:${digits(value ~/ 60 % 60)}:${digits(value % 60)}';
    final countdown = seconds == null
        ? null
        : seconds <= 0
        ? 'Not started \u00b7 ${durationText(seconds.abs())} overdue'
        : 'Starts in ${durationText(seconds)}';
    final color = status == 'PAYMENT_FAILED'
        ? const Color(0xFFF04452)
        : failed
        ? CustomerColors.error
        : CustomerColors.action;
    final badgeStyle = CustomerTypography.card.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );
    final icon = switch (status) {
      'CONFIRMED' || 'COMPLETED' => Icons.check_circle_rounded,
      'IN_PROGRESS' => Icons.play_circle_outline_rounded,
      'CANCELLED' ||
      'EXPIRED' ||
      'REJECTED' ||
      'PAYMENT_FAILED' => Icons.cancel_outlined,
      _ => Icons.schedule_rounded,
    };
    final badge = Container(
      key: const ValueKey('booking-status-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: status == 'PAYMENT_FAILED'
            ? const Color(0xFFFFE2DC)
            : failed
            ? const Color(0xFFFFE8EC)
            : const Color(0xFFE3F7F2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: badgeStyle)),
        ],
      ),
    );
    if (status != 'CONFIRMED' || countdown == null) {
      return Align(alignment: Alignment.centerLeft, child: badge);
    }
    if (overdue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('booking-start-countdown'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFDEDE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE3E3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: CustomerColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not started yet',
                        style: CustomerTypography.compactStrong.copyWith(
                          color: const Color(0xFF934343),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            durationText(seconds.abs()),
                            style: CustomerTypography.section.copyWith(
                              color: CustomerColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'overdue',
                            style: CustomerTypography.compact.copyWith(
                              color: const Color(0xFF934343),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final span = TextSpan(
      style: CustomerTypography.compact.copyWith(
        color: CustomerColors.secondaryText,
      ),
      children: seconds != null && seconds > 0
          ? [
              const TextSpan(text: 'Starts in '),
              TextSpan(
                text: countdown.substring('Starts in '.length),
                style: CustomerTypography.card.copyWith(
                  color: const Color(0xFF101D42),
                ),
              ),
            ]
          : [
              TextSpan(
                text: countdown,
                style: CustomerTypography.card.copyWith(
                  color: CustomerColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final badgeMeasure = TextPainter(
      text: TextSpan(text: label, style: badgeStyle),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final timeMeasure = TextPainter(
      text: span,
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final requiredWidth = badgeMeasure.width + 50 + 25 + timeMeasure.width + 27;
    badgeMeasure.dispose();
    timeMeasure.dispose();
    final time = Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.access_time_rounded,
            color: overdue ? CustomerColors.error : CustomerColors.action,
            size: 20,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            span,
            key: const ValueKey('booking-start-countdown'),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        if (requiredWidth <= bounds.maxWidth) {
          return Row(
            children: [
              badge,
              const SizedBox(width: 12),
              Container(width: 1, height: 24, color: const Color(0xFFD6DEE9)),
              const SizedBox(width: 12),
              Expanded(child: time),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [badge, const SizedBox(height: 10), time],
        );
      },
    );
  }
}

GeoPoint? bookingLocationPoint(Map<String, dynamic> booking) {
  // BookingResponse uses flat latitude/longitude; draft/tracking projections
  // may instead carry a nested location. Never substitute the device location.
  if (booking['latitude'] != null || booking['longitude'] != null) {
    try {
      return GeoPoint.parse(booking);
    } catch (_) {}
  }
  for (final key in ['meetingPoint', 'pickup', 'mapPoint']) {
    final value = booking[key];
    if (value is Map) {
      try {
        return GeoPoint.parse(Map<String, dynamic>.from(value));
      } catch (_) {}
    }
  }
  return null;
}

/// A real service pin only. Missing coordinates are never replaced by device GPS
/// or a sample map, and no provider journey/road geometry is invented.
class BookingLocationPreview extends ConsumerWidget {
  const BookingLocationPreview({super.key, this.point, this.label});
  final GeoPoint? point;
  final String? label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = point;
    return Container(
      key: const ValueKey('booking-location-preview'),
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7F6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: p == null
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: CustomerColors.action,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label ?? 'Service location',
                          style: CustomerTypography.card,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The service location is not available on the map.',
                          style: CustomerTypography.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : SizedBox(
              height: 174,
              child: ref.watch(customerMapBuilderProvider)(
                CustomerMapState(
                  camera: CameraPosition(
                    target: LatLng(p.latitude, p.longitude),
                    zoom: 15,
                  ),
                  onCreated: (_) {},
                  onSelect: null,
                  markers: {
                    Marker(
                      markerId: const MarkerId('booking-service-location'),
                      position: LatLng(p.latitude, p.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueCyan,
                      ),
                      infoWindow: InfoWindow(
                        title: label ?? 'Service location',
                      ),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('booking-location-area'),
                      center: LatLng(p.latitude, p.longitude),
                      radius: 70,
                      fillColor: CustomerColors.action.withValues(alpha: .12),
                      strokeColor: CustomerColors.action.withValues(alpha: .25),
                      strokeWidth: 1,
                    ),
                  },
                ),
              ),
            ),
    );
  }
}

class BookingScheduleLocation extends StatelessWidget {
  const BookingScheduleLocation({
    super.key,
    required this.schedule,
    this.duration,
    required this.location,
  });
  final String schedule, location;
  final String? duration;
  Widget _tile(IconData icon, String label, String value, {String? badge}) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: CustomerColors.selection,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: CustomerColors.action, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: CustomerTypography.compactStrong.copyWith(
                      color: CustomerColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: CustomerTypography.compactStrong.copyWith(
                      color: const Color(0xFF101D42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        badge,
                        style: CustomerTypography.compactStrong.copyWith(
                          color: CustomerColors.action,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final a = _tile(
        Icons.calendar_today_outlined,
        'Service schedule',
        schedule,
        badge: duration,
      );
      final b = _tile(Icons.place_outlined, 'Location', location);
      if (bounds.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(12) > 17) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [a, const SizedBox(height: 10), b],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        ),
      );
    },
  );
}
