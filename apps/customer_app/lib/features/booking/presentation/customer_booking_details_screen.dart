import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'customer_payment_requests.dart';
import 'booking_details_skeleton.dart';
import 'customer_booking_start_code.dart';
import 'customer_booking_progress.dart';
import 'customer_booking_rating.dart';
import 'customer_booking_providers.dart';
import 'customer_tracking_status.dart';
import 'customer_service_timer.dart';
import 'customer_booking_auto_cancel.dart';
import 'customer_booking_cancellation.dart';
import 'booking_details_reference.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/presentation/customer_bottom_navigation.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../application/customer_booking_history.dart';
import '../application/customer_booking_option_name.dart';
import '../application/customer_request_recovery.dart';
import '../domain/booking_models.dart';

class BookingDetailsExtras {
  BookingDetailsExtras({
    required this.jobId,
    this.serviceName,
    List<ProviderCandidate> providers = const [],
    Map<String, String> answerLabels = const {},
  }) : providers = List.unmodifiable(providers),
       answerLabels = Map.unmodifiable(answerLabels);
  final int jobId;
  final String? serviceName;
  final List<ProviderCandidate> providers;
  final Map<String, String> answerLabels;
}

// Session-only display context. The booking API remains the source of truth;
// discard names/photos/field labels whenever the authenticated session changes.
final customerBookingDetailsExtrasProvider =
    Provider.family<Map<int, BookingDetailsExtras>, int>((ref, userId) {
      ref.watch(customerAuthControllerProvider);
      return <int, BookingDetailsExtras>{};
    }, dependencies: [customerAuthControllerProvider]);

class CustomerBookingDetailsScreen extends ConsumerStatefulWidget {
  const CustomerBookingDetailsScreen({
    super.key,
    required this.jobId,
    this.extras,
  });
  final int jobId;
  final BookingDetailsExtras? extras;

  @override
  ConsumerState<CustomerBookingDetailsScreen> createState() =>
      _CustomerBookingDetailsScreenState();
}

class _CustomerBookingDetailsScreenState
    extends ConsumerState<CustomerBookingDetailsScreen> {
  Map<String, dynamic>? _freshBooking;
  int? _freshOwner;
  bool _showRatingOnCompletion = false;
  bool _reviewSaved = false;
  int? _ratingOwner, _ratingJob;
  String? _previousBookingStatus;
  int get jobId => widget.jobId;
  BookingDetailsExtras? get extras => widget.extras;
  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(customerAuthControllerProvider).user?.id;
    if (_ratingOwner != owner || _ratingJob != jobId) {
      _ratingOwner = owner;
      _ratingJob = jobId;
      _showRatingOnCompletion = false;
      _reviewSaved = false;
      _previousBookingStatus = null;
    }
    // Keep recovery alive across history reloads. Its subscription must not be
    // owned solely by a child that is temporarily replaced by a loading view.
    ref.watch(customerRequestRecoveryProvider);
    if (_freshOwner != owner || _freshBooking?['jobId'] != jobId) {
      _freshOwner = owner;
      _freshBooking = null;
    }
    final history = owner == null
        ? null
        : ref.watch(customerBookingHistoryProvider(owner));
    final remembered = owner == null
        ? null
        : ref.watch(customerBookingDetailsExtrasProvider(owner))[jobId];
    final supplied = remembered ?? (extras?.jobId == jobId ? extras : null);
    void retry() {
      if (owner != null) ref.invalidate(customerBookingHistoryProvider(owner));
    }

    return BookingDetailsPage(
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/opportunities'),
      child: history == null
          ? const BookingDetailsPageSkeleton()
          : history.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              skipError: history.hasValue,
              loading: () => const BookingDetailsPageSkeleton(),
              error: (_, _) => _DetailsUnavailable(onRetry: retry),
              data: (rows) {
                final row = rows
                    .where((row) => row['jobId'] == jobId)
                    .firstOrNull;
                if (row == null) {
                  // Cached history can predate a newly confirmed booking. An
                  // in-flight refresh is still loading, not a missing booking.
                  if (history.isLoading) {
                    return const BookingDetailsPageSkeleton();
                  }
                  return _DetailsUnavailable(onRetry: retry);
                }
                // A local pull-to-refresh snapshot may predate payment on the
                // pushed retry route. Let funded history replace that snapshot.
                if (_freshBooking?['status'] == 'AWAITING_PAYMENT' &&
                    {
                      'CONFIRMED',
                      'IN_PROGRESS',
                      'AWAITING_COMPLETION_CONFIRMATION',
                      'COMPLETED',
                    }.contains(row['status']) &&
                    {
                      'PAID',
                      'RESERVED',
                      'SETTLED',
                    }.contains(row['paymentStatus'])) {
                  _freshBooking = null;
                }
                if (_freshBooking != null &&
                    row['status'] != _freshBooking!['status'] &&
                    {
                      'CANCELLED',
                      'IN_PROGRESS',
                      'AWAITING_COMPLETION_CONFIRMATION',
                      'COMPLETED',
                    }.contains(row['status'])) {
                  _freshBooking = null;
                }
                final booking = _freshBooking ?? row;
                if (_previousBookingStatus != null &&
                    _previousBookingStatus != 'COMPLETED' &&
                    booking['status'] == 'COMPLETED') {
                  _showRatingOnCompletion = true;
                }
                _previousBookingStatus = booking['status'] as String?;
                final discovery = ref.watch(customerDiscoveryProvider);
                final serviceId = booking['serviceTypeId'] as int?;
                final optionId = booking['optionId'] as int?;
                final marketId =
                    booking['marketId'] as int? ?? discovery.activeMarket?.id;
                String? optionTitle =
                    bookingOptionName(booking) ?? supplied?.serviceName;
                if (optionTitle == null &&
                    serviceId != null &&
                    optionId != null) {
                  optionTitle = discovery
                      .optionsFor(serviceId)
                      .options
                      .where((o) => o.id == optionId)
                      .firstOrNull
                      ?.name;
                  if (optionTitle == null &&
                      owner != null &&
                      marketId != null &&
                      marketId > 0) {
                    optionTitle = ref
                        .watch(
                          customerBookingOptionNameProvider((
                            owner: owner,
                            market: marketId,
                            service: serviceId,
                            option: optionId,
                          )),
                        )
                        .asData
                        ?.value;
                  }
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerBookingHistoryProvider(owner!));
                    final refreshed = await ref.read(
                      customerBookingHistoryProvider(owner).future,
                    );
                    final latest = refreshed
                        .where((row) => row['jobId'] == jobId)
                        .firstOrNull;
                    if (mounted &&
                        latest != null &&
                        ref.read(customerAuthControllerProvider).user?.id ==
                            owner) {
                      setState(() => _freshBooking = latest);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomerBookingDetailsView(
                          booking: booking,
                          reviewSaved: _reviewSaved,
                          onAutoCancelChanged: (latest) {
                            if (mounted &&
                                ref
                                        .read(customerAuthControllerProvider)
                                        .user
                                        ?.id ==
                                    owner) {
                              setState(() => _freshBooking = latest);
                            }
                          },
                          scheduledStart: bookingScheduledInstant(
                            booking,
                            booking['marketTimezone'] as String? ??
                                booking['timezone'] as String? ??
                                ref
                                    .read(customerDiscoveryProvider)
                                    .markets
                                    .where((m) => m.id == booking['marketId'])
                                    .firstOrNull
                                    ?.timezone,
                          ),
                          paymentRecovery: CustomerPaymentRequests(
                            jobId: jobId,
                            detailsStyle: true,
                            awaitingPayment:
                                booking['status'] == 'AWAITING_PAYMENT',
                            requestId: booking['requestId'] is int
                                ? booking['requestId'] as int
                                : null,
                          ),
                          serviceName:
                              optionTitle ??
                              (optionId == null
                                  ? 'Service option'
                                  : 'Service option #$optionId'),
                          providers: supplied?.providers ?? [],
                          assignedProviders: CustomerBookingProviders(
                            key: ValueKey('assigned-providers-$owner-$jobId'),
                            jobId: jobId,
                            status: booking['status'] as String? ?? '',
                          ),
                          answerLabels: supplied?.answerLabels ?? {},
                          cancellation:
                              {
                                    'PAID',
                                    'RESERVED',
                                    'REFUNDED',
                                    'PARTIALLY_REFUNDED',
                                    'CANCELLATION_SETTLED',
                                  }.contains(booking['paymentStatus']) &&
                                  {
                                    'CONFIRMED',
                                    'CANCELLED',
                                  }.contains(booking['status'])
                              ? CustomerBookingCancellation(
                                  key: ValueKey('cancel-$owner-$jobId'),
                                  booking: booking,
                                  onChanged: (latest) {
                                    if (mounted &&
                                        ref
                                                .read(
                                                  customerAuthControllerProvider,
                                                )
                                                .user
                                                ?.id ==
                                            owner &&
                                        latest['jobId'] == jobId) {
                                      setState(() => _freshBooking = latest);
                                    }
                                  },
                                )
                              : null,
                          onBookings: () => context.go('/opportunities'),
                          startCode: CustomerBookingStartCode(
                            key: ValueKey('booking-start-code-$jobId'),
                            booking: booking,
                            scheduledStart: bookingScheduledInstant(
                              booking,
                              booking['marketTimezone'] as String? ??
                                  booking['timezone'] as String? ??
                                  ref
                                      .read(customerDiscoveryProvider)
                                      .markets
                                      .where((m) => m.id == booking['marketId'])
                                      .firstOrNull
                                      ?.timezone,
                            ),
                          ),
                          rating: booking['status'] == 'COMPLETED'
                              ? CustomerBookingRating(
                                  onSavedState: (saved) {
                                    if (mounted &&
                                        _reviewSaved != saved &&
                                        ref
                                                .read(
                                                  customerAuthControllerProvider,
                                                )
                                                .user
                                                ?.id ==
                                            owner) {
                                      setState(() => _reviewSaved = saved);
                                    }
                                  },
                                  autoOpen: _showRatingOnCompletion,
                                  key: ValueKey('booking-rating-$owner-$jobId'),
                                  jobId: jobId,
                                )
                              : null,
                          tracking:
                              booking['deliveryMode'] ==
                                      'PROVIDER_TO_CUSTOMER' &&
                                  {
                                    'CONFIRMED',
                                    'IN_PROGRESS',
                                  }.contains(booking['status'])
                              ? CustomerTrackingStatus(
                                  compact: true,
                                  booking: booking,
                                  key: ValueKey('tracking-$owner-$jobId'),
                                  jobId: jobId,
                                  team:
                                      (booking['providerIds'] as List? ?? [])
                                          .length >
                                      1,
                                )
                              : null,
                          serviceProgress: CustomerBookingProgress(
                            embedded: true,
                            compact: true,
                            key: ValueKey('booking-progress-$jobId'),
                            booking: booking,
                            onBookingChanged: (latest) {
                              if (mounted &&
                                  ref
                                          .read(customerAuthControllerProvider)
                                          .user
                                          ?.id ==
                                      owner &&
                                  latest['jobId'] == jobId) {
                                setState(() {
                                  if (booking['status'] != 'COMPLETED' &&
                                      latest['status'] == 'COMPLETED') {
                                    _showRatingOnCompletion = true;
                                  }
                                  _freshBooking = latest;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Consistent Customer chrome for booking details.
class BookingDetailsPage extends StatelessWidget {
  const BookingDetailsPage({
    super.key,
    required this.onBack,
    required this.child,
  });
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    const toolbarHeight = 64.0;
    const cornerRadius = 30.0;
    final headerHeight = MediaQuery.paddingOf(context).top + toolbarHeight;
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: toolbarHeight,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          foregroundColor: CustomerColors.text,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Booking details',
            style: CustomerTypography.section.copyWith(
              color: CustomerColors.text,
            ),
          ),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE7F5F2),
              foregroundColor: CustomerColors.primary,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: headerHeight + cornerRadius,
              child: const BookingDetailsHeaderBackground(),
            ),
            Padding(
              padding: EdgeInsets.only(top: headerHeight),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(cornerRadius),
                ),
                child: ColoredBox(
                  color: const Color(0xFFF4F8FC),
                  child: SafeArea(top: false, child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsUnavailable extends StatelessWidget {
  const _DetailsUnavailable({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      key: const ValueKey('booking-details-error'),
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (bounds.maxHeight - 32).clamp(0, double.infinity),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CustomerColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: CustomerColors.selection,
                      child: Icon(
                        Icons.event_note_outlined,
                        size: 30,
                        color: CustomerColors.action,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Booking details are not available yet.',
                    textAlign: TextAlign.center,
                    style: CustomerTypography.section,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try again to load the latest booking information.',
                    textAlign: TextAlign.center,
                    style: CustomerTypography.body.copyWith(
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry booking details'),
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

String bookingStatusLabel(Object? raw) => switch (raw) {
  'CONFIRMED' => 'Confirmed',
  'IN_PROGRESS' => 'In progress',
  'COMPLETED' => 'Completed',
  'AWAITING_COMPLETION_CONFIRMATION' => 'Awaiting completion confirmation',
  'AWAITING_PAYMENT' => 'Awaiting payment',
  'PENDING' => 'Pending',
  'CANCELLED' => 'Cancelled',
  'EXPIRED' => 'Expired',
  'REJECTED' => 'Declined',
  _ => 'Status unavailable',
};

bool bookingIsClosedUnpaid(Object? paymentStatus, Object? bookingStatus) =>
    {'CANCELLED', 'EXPIRED', 'REJECTED'}.contains(bookingStatus) &&
    {'PENDING', 'NOT_STARTED'}.contains(paymentStatus);

String bookingPaymentLabel(Object? raw, {Object? bookingStatus}) =>
    bookingIsClosedUnpaid(raw, bookingStatus)
    ? 'Not paid'
    : switch (raw) {
        'RESERVED' => 'Funds reserved',
        'PAID' => 'Paid',
        'SETTLED' => 'Settled',
        'PENDING' => 'Pending payment',
        'FAILED' => 'Payment failed',
        'REFUNDED' => 'Refunded',
        'PARTIALLY_REFUNDED' => 'Partially refunded',
        'CANCELLATION_SETTLED' => 'Cancellation settled',
        'NOT_STARTED' => 'Not started',
        _ => 'Status unavailable',
      };

class CustomerBookingDetailsView extends StatelessWidget {
  const CustomerBookingDetailsView({
    super.key,
    required this.booking,
    required this.onBookings,
    this.serviceName,
    this.providers = const [],
    this.answerLabels = const {},
    this.startCode,
    this.serviceProgress,
    this.rating,
    this.tracking,
    this.cancellation,
    this.assignedProviders,
    this.paymentRecovery,
    this.scheduledStart,
    this.reviewSaved = false,
    this.onAutoCancelChanged,
  });
  final Map<String, dynamic> booking;
  final String? serviceName;
  final List<ProviderCandidate> providers;
  final Map<String, String> answerLabels;
  final VoidCallback onBookings;
  final ValueChanged<Map<String, dynamic>>? onAutoCancelChanged;
  final Widget? startCode;
  final Widget? serviceProgress;
  final Widget? rating;
  final Widget? tracking;
  final Widget? cancellation;
  final Widget? assignedProviders;
  final Widget? paymentRecovery;
  final DateTime? scheduledStart;
  final bool reviewSaved;

  Widget _section(String title, List<Widget> children) {
    final provider = title == 'Your provider' || title == 'Your providers';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: provider ? EdgeInsets.zero : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CustomerColors.border),
        boxShadow: provider
            ? null
            : const [
                BoxShadow(
                  color: Color(0x080F666B),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!provider) ...[
            Text(
              title,
              style: CustomerTypography.section.copyWith(
                color: const Color(0xFF101D42),
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: CustomerColors.border),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = booking['status'] == 'CANCELLED';
    final completed = booking['status'] == 'COMPLETED';
    final unpaid = {
      'PENDING',
      'AWAITING_PAYMENT',
      'PAYMENT_FAILED',
    }.contains(booking['status']);
    final start = booking['startDatetime'] ?? booking['requestedPickupTime'];
    final answers = booking['answers'];
    final details = answers is Map
        ? answers.entries
              .where((e) => e.value != null && '${e.value}'.trim().isNotEmpty)
              .toList()
        : <MapEntry<dynamic, dynamic>>[];
    final currency = booking['currencyCode'];
    final amount = walletMoney(booking['expectedAmount'])
        .replaceFirst('Rs.', currency == 'LKR' ? 'Rs.' : '$currency');
    final providerCard =
        assignedProviders ??
        _section('Your provider', [
          const Text('Assigned provider', style: CustomerTypography.card),
          const Text(
            'Profile details are not available yet.',
            style: CustomerTypography.compact,
          ),
        ]);
    final map =
        tracking ??
        (booking['deliveryMode'] == 'ONLINE'
            ? const SizedBox.shrink()
            : BookingLocationPreview(
                point: bookingLocationPoint(booking),
                label: booking['meetingPointName'] as String?,
              ));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          key: const ValueKey('booking-details-reference-card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE8F1F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F666B),
                blurRadius: 18,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    if (!unpaid) {
                      return BookingDetailsIdentity(
                        name:
                            bookingOptionName(booking) ??
                            serviceName ??
                            'Service option',
                        jobId: booking['jobId'],
                        status: booking['status'] as String? ?? '',
                        start: scheduledStart,
                      );
                    }
                    final recovery = ref.watch(customerRequestRecoveryProvider);
                    return ListenableBuilder(
                      listenable: recovery,
                      builder: (context, _) {
                        final request = recovery.requests.values
                            .where((row) => row['jobId'] == booking['jobId'])
                            .firstOrNull;
                        final failedPayment =
                            unpaid &&
                            (booking['paymentStatus'] == 'FAILED' ||
                                request?['paymentStatus'] == 'FAILED' ||
                                DateTime.tryParse(
                                      '${request?['paymentRetryStartedAt']}',
                                    ) !=
                                    null);
                        return BookingDetailsIdentity(
                          name:
                              bookingOptionName(booking) ??
                              serviceName ??
                              'Service option',
                          jobId: booking['jobId'],
                          status: failedPayment
                              ? 'PAYMENT_FAILED'
                              : booking['status'] as String? ?? '',
                          start: scheduledStart,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                CustomerBookingAutoCancel(
                  booking: booking,
                  onChanged: onAutoCancelChanged,
                ),
                CustomerServiceTimer(booking: booking),
                ?paymentRecovery,
                if (!cancelled && !completed) ?startCode,
                map,
                if (!completed && !unpaid) ...[
                  const SizedBox(height: 12),
                  providerCard,
                  const SizedBox(height: 12),
                ],
                if (completed) ...[
                  if (!reviewSaved) ?rating,
                  providerCard,
                  const SizedBox(height: 12),
                ],
                Opacity(
                  opacity: cancelled ? .65 : 1,
                  child: BookingScheduleLocation(
                    schedule: bookingReferenceSchedule(context, start, null),
                    location:
                        booking['meetingPointName'] as String? ??
                        (booking['deliveryMode'] == 'ONLINE'
                            ? 'Online service'
                            : 'Service location not provided'),
                  ),
                ),
                if (booking['destinationAddress']
                    case final String destination) ...[
                  const SizedBox(height: 10),
                  _summaryLine(Icons.flag_outlined, 'Destination', destination),
                ],
                const SizedBox(height: 12),
                Opacity(
                  opacity: cancelled ? .65 : 1,
                  child: _paymentSummary(context, amount),
                ),
                const SizedBox(height: 12),
                if (cancelled)
                  Container(
                    key: const ValueKey('cancelled-booking-start-code'),
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Not available for a cancelled booking.',
                      style: CustomerTypography.compact,
                    ),
                  ),
                if (!cancelled) ?serviceProgress,
                if (details.isNotEmpty)
                  Container(
                    key: const ValueKey('booking-patient-details'),
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFF8FAFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CustomerColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C0F666B),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _AutoRevealDetailsExpansion(
                      builder: (onExpanded) => ExpansionTile(
                        onExpansionChanged: onExpanded,
                        expansionAnimationStyle: const AnimationStyle(
                          duration: Duration(milliseconds: 200),
                        ),
                        key: const PageStorageKey('booking-patient-expansion'),
                        iconColor: const Color(0xFF58627B),
                        collapsedIconColor: const Color(0xFF58627B),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          14,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: const CircleAvatar(
                          radius: 22,
                          backgroundColor: CustomerColors.selection,
                          child: Icon(
                            Icons.people_outline_rounded,
                            color: CustomerColors.action,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          details.any(
                                (e) =>
                                    '${e.key}'.toUpperCase().startsWith('CG_'),
                              )
                              ? 'Patient details'
                              : 'Your booking details',
                          style: CustomerTypography.section.copyWith(
                            color: const Color(0xFF101D42),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: _answerWidgets(details),
                      ),
                    ),
                  ),
                if (!completed || reviewSaved) ?rating,
                ?cancellation,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentSummary(BuildContext context, String amount) {
    final badge = _DetailsBadge(
      subdued: booking['paymentStatus'] == 'FAILED',
      backgroundColor: switch (booking['paymentStatus']) {
        'PAID' => const Color(0xFFD7F3E4),
        'REFUNDED' => const Color(0xFFDDEEFF),
        'RESERVED' => const Color(0xFFFFE3A0),
        _ => const Color(0xFFE2E9EF),
      },
      foregroundColor: switch (booking['paymentStatus']) {
        'PAID' => const Color(0xFF17653B),
        'REFUNDED' => const Color(0xFF245C88),
        'RESERVED' => const Color(0xFF805411),
        _ => const Color(0xFF46566A),
      },
      label: bookingPaymentLabel(
        booking['paymentStatus'],
        bookingStatus: booking['status'],
      ),
      pending:
          !bookingIsClosedUnpaid(booking['paymentStatus'], booking['status']) &&
          {'PENDING', 'NOT_STARTED'}.contains(booking['paymentStatus']),
    );
    final method = switch (booking['paymentMethod']) {
      'WALLET' => 'BThere Wallet',
      'CARD' => 'Credit / Debit Card',
      'CASH' => 'Cash',
      _ => 'Payment method not specified',
    };
    return Semantics(
      label: method,
      child: Container(
        key: const ValueKey('booking-payment-summary'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE3F8F6), Color(0xFFF0FBFA)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final amountStyle = CustomerTypography.section.copyWith(
              color: const Color(0xFF101D42),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            );
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      CustomerNavigationTab.wallet.asset(false),
                      width: 28,
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        CustomerColors.action,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: CustomerTypography.compactStrong.copyWith(
                          color: CustomerColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(amount, style: amountStyle, maxLines: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bounds.maxWidth * .38),
                  child: FittedBox(fit: BoxFit.scaleDown, child: badge),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryLine(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFC),
      borderRadius: BorderRadius.circular(18),
    ),
    child: _DetailLine(icon: icon, label: label, value: value),
  );

  List<Widget> _answerWidgets(List<MapEntry<dynamic, dynamic>> entries) {
    String label(MapEntry<dynamic, dynamic> entry) =>
        answerLabels['${entry.key}'] ?? _humanize('${entry.key}');
    bool compact(MapEntry<dynamic, dynamic> entry) =>
        RegExp(r'\b(ward|bed)\b', caseSensitive: false).hasMatch(label(entry));
    bool note(MapEntry<dynamic, dynamic> entry) => RegExp(
      r'\b(notes?|additional|information)\b',
      caseSensitive: false,
    ).hasMatch(label(entry));
    final small = entries.where(compact).toList();
    final rows = entries
        .where((entry) => !compact(entry) && !note(entry))
        .toList();
    return [
      for (var index = 0; index < rows.length; index++)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PatientDetail(
              label: label(rows[index]),
              value: _answer(rows[index].value),
            ),
            if (index < rows.length - 1)
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
          ],
        ),
      if (small.isNotEmpty)
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final entry in small)
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(12) > 16
                      ? bounds.maxWidth
                      : (bounds.maxWidth - 10) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _PatientDetail(
                      label: label(entry),
                      value: _answer(entry.value),
                      vertical: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      for (final entry in entries.where(
        (entry) => note(entry) && !compact(entry),
      ))
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CustomerColors.selection,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _PatientDetail(
            label: label(entry),
            value: _answer(entry.value),
            vertical: true,
          ),
        ),
    ];
  }

  String _humanize(String code) {
    final value = code
        .replaceFirst(RegExp(r'^CG_', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .toLowerCase();
    return value.isEmpty
        ? 'Detail'
        : '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _answer(Object? value) => switch (value) {
    bool flag => flag ? 'Yes' : 'No',
    String text => text,
    num number => '$number',
    List values =>
      values.map((v) => v is Map ? 'Attached file' : _answer(v)).join(', '),
    Map _ => 'Attached information',
    _ => 'Not specified',
  };
}

class _PatientDetail extends StatelessWidget {
  const _PatientDetail({
    required this.label,
    required this.value,
    this.vertical = false,
  });
  final String label, value;
  final bool vertical;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final stacked =
          vertical ||
          bounds.maxWidth < 240 ||
          MediaQuery.textScalerOf(context).scale(12) > 16;
      final caption = Text(
        label,
        style: CustomerTypography.compactStrong.copyWith(
          color: CustomerColors.secondaryText,
        ),
      );
      final answer = Text(
        value,
        style: CustomerTypography.card.copyWith(
          color: const Color(0xFF101D42),
          fontWeight: FontWeight.w700,
        ),
      );
      return Padding(
        padding: EdgeInsets.symmetric(vertical: vertical ? 0 : 9),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [caption, const SizedBox(height: 4), answer],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: caption),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: answer),
                ],
              ),
      );
    },
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDFF6F3),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 21, color: CustomerColors.action),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: CustomerTypography.card.copyWith(
                  color: const Color(0xFF101D42),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailsBadge extends StatelessWidget {
  const _DetailsBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.subdued = false,
    this.pending = false,
  });
  final String label;
  final Color backgroundColor, foregroundColor;
  final bool subdued, pending;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: pending
          ? const Color(0xFFFFE3A0)
          : subdued
          ? const Color(0xFFFFE2DC)
          : backgroundColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending) ...[
          const Icon(
            Icons.credit_card_rounded,
            size: 15,
            color: Color(0xFF805411),
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: CustomerTypography.compactStrong.copyWith(
              fontWeight: FontWeight.w700,
              color: pending
                  ? const Color(0xFF805411)
                  : subdued
                  ? const Color(0xFFF04452)
                  : foregroundColor,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Reveal newly expanded details after the tile finishes laying out. No outer
/// scroll controller is required, so this also works in the booking UI lab.
class _AutoRevealDetailsExpansion extends StatefulWidget {
  const _AutoRevealDetailsExpansion({required this.builder});
  final Widget Function(ValueChanged<bool>) builder;
  @override
  State<_AutoRevealDetailsExpansion> createState() =>
      _AutoRevealDetailsExpansionState();
}

class _AutoRevealDetailsExpansionState
    extends State<_AutoRevealDetailsExpansion> {
  Timer? reveal;
  bool isExpanded = false;
  void changed(bool expanded) {
    reveal?.cancel();
    isExpanded = expanded;
    if (!expanded) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    reveal = Timer(
      reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
      () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isExpanded ||
              !mounted ||
              ModalRoute.of(context)?.isCurrent == false) {
            return;
          }
          final scrollable = Scrollable.maybeOf(context);
          final box = context.findRenderObject();
          if (scrollable == null || box is! RenderBox || !box.hasSize) return;
          final fits = box.size.height <= scrollable.position.viewportDimension;
          Scrollable.ensureVisible(
            context,
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: fits ? 1 : 0,
            alignmentPolicy: fits
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.explicit,
          );
        });
        WidgetsBinding.instance.scheduleFrame();
      },
    );
  }

  @override
  void dispose() {
    reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(changed);
}
