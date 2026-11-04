import 'customer_booking_details_screen.dart';
import '../../discovery/presentation/customer_bottom_navigation.dart';
import '../../../app/widgets/customer_top_bar.dart';
export '../application/customer_booking_history.dart'
    show customerBookingHistoryProvider;
import '../application/customer_booking_history.dart';
import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import 'booking_ui_format.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;

class CustomerBookingsScreen extends ConsumerWidget {
  const CustomerBookingsScreen({super.key, this.asOpportunities = false});
  final bool asOpportunities;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider), id = auth.user?.id;
    final history = id == null
        ? null
        : ref.watch(customerBookingHistoryProvider(id));
    final services = ref.watch(customerDiscoveryProvider).services;
    final names = {for (final service in services) service.id: service.name};
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F9F9),
        appBar: asOpportunities
            ? null
            : AppBar(
                title: const Text('My bookings'),
                leading: IconButton(
                  tooltip: 'Back to Home',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
        bottomNavigationBar: const CustomerBottomNavigation(
          selected: CustomerNavigationTab.opportunities,
        ),
        body: Column(
          children: [
            if (asOpportunities) const CustomerTopBar(),
            Expanded(
              child: history == null
                  ? const BThereLoadingState(label: 'Loading bookings')
                  : history.when(
                      loading: () =>
                          const BThereLoadingState(label: 'Loading bookings'),
                      error: (_, _) => BThereStateView(
                        title: 'Unable to load bookings',
                        message: 'Please try again.',
                        action: TextButton(
                          onPressed: () => ref.invalidate(
                            customerBookingHistoryProvider(id!),
                          ),
                          child: const Text('Retry booking history'),
                        ),
                      ),
                      data: (rows) => CustomerOpportunitiesBody(
                        bookings: rows,
                        serviceNames: names,
                        onRefresh: () async {
                          ref.invalidate(customerBookingHistoryProvider(id!));
                          await ref.read(
                            customerBookingHistoryProvider(id).future,
                          );
                        },
                        onOpen: (booking) => context.push(
                          '/bookings/${booking['jobId']}',
                          extra: BookingDetailsExtras(
                            jobId: booking['jobId'] as int,
                            serviceName: names[booking['serviceTypeId']],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerOpportunitiesBody extends StatefulWidget {
  const CustomerOpportunitiesBody({
    super.key,
    required this.bookings,
    required this.onRefresh,
    required this.onOpen,
    this.serviceNames = const {},
  });
  final List<Map<String, dynamic>> bookings;
  final Map<int, String> serviceNames;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<CustomerOpportunitiesBody> createState() =>
      _CustomerOpportunitiesBodyState();
}

class _CustomerOpportunitiesBodyState extends State<CustomerOpportunitiesBody> {
  String _filter = 'All';
  String _group(Object? status) => switch (status) {
    'COMPLETED' => 'Completed',
    'CANCELLED' || 'REJECTED' || 'EXPIRED' => 'Cancelled',
    _ => 'Active',
  };
  @override
  Widget build(BuildContext context) {
    final rows = widget.bookings
        .where((b) => _filter == 'All' || _group(b['status']) == _filter)
        .toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Bookings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: CustomerColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F4F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.bookings.length}',
                  style: const TextStyle(
                    color: CustomerColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep track of your care, all in one place.',
            style: TextStyle(fontSize: 13, color: CustomerColors.secondaryText),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in [
                  'All',
                  'Active',
                  'Completed',
                  'Cancelled',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                      selectedColor: CustomerColors.action,
                      showCheckmark: false,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _filter == filter
                            ? CustomerColors.action
                            : const Color(0xFFE0EBEE),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _filter == filter
                            ? Colors.white
                            : CustomerColors.secondaryText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${_filter == 'All' ? 'All bookings' : '$_filter bookings'} · ${rows.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: CustomerColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    size: 48,
                    color: CustomerColors.action,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.bookings.isEmpty
                        ? 'No bookings yet.'
                        : 'No ${_filter.toLowerCase()} bookings.',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CustomerColors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your service bookings will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          for (final booking in rows)
            BookingSummaryTile(
              booking: booking,
              name:
                  widget.serviceNames[booking['serviceTypeId']] ??
                  'Service booking',
              onTap: () => widget.onOpen(booking),
            ),
        ],
      ),
    );
  }
}

class CustomerRecentBookings extends ConsumerWidget {
  const CustomerRecentBookings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    final id = auth.user?.id;
    if (id == null) return const SizedBox.shrink();
    final history = ref.watch(customerBookingHistoryProvider(id));
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: BThereLoadingState(
          label: 'Loading recent bookings',
          compact: true,
        ),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(customerBookingHistoryProvider(id)),
        child: const Text('Unable to load recent bookings · Retry'),
      ),
      data: (rows) => rows.isEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEBEDF5)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: CustomerColors.selection,
                    child: Icon(Icons.history_rounded, color: catalogTeal),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent bookings yet.',
                          style: TextStyle(
                            color: catalogInk,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your services will appear here after booking.',
                          style: TextStyle(
                            color: catalogMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final row in rows.take(3))
                  BookingHistoryTile(booking: row),
              ],
            ),
    );
  }
}

class BookingHistoryTile extends ConsumerWidget {
  const BookingHistoryTile({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(customerDiscoveryProvider).services;
    final service = services
        .where((s) => s.id == booking['serviceTypeId'])
        .firstOrNull;
    final name = service?.name ?? 'Service booking';
    final appearance = service == null
        ? const ServiceAppearance(
            catalogTeal,
            Icons.volunteer_activism_outlined,
          )
        : ServiceAppearance.forService(service, 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEBEDF5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('customer-booking-${booking['jobId']}'),
          onTap: () => context.push(
            '/bookings/${booking['jobId']}',
            extra: BookingDetailsExtras(
              jobId: booking['jobId'] as int,
              serviceName: name,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogIcon(
                  appearance: appearance,
                  url: service?.iconUrl,
                  size: 32,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: catalogInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bookingDisplayTime(
                          context,
                          (booking['startDatetime'] ??
                                  booking['requestedPickupTime'])
                              as String?,
                        ),
                        style: const TextStyle(
                          color: catalogMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _RecentStatus(
                            label: bookingStatusLabel(booking['status']),
                            highlighted: true,
                            compact: true,
                          ),
                          _RecentStatus(
                            compact: true,
                            label: bookingPaymentLabel(
                              booking['paymentStatus'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: catalogTeal,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentStatus extends StatelessWidget {
  const _RecentStatus({
    required this.label,
    this.highlighted = false,
    this.compact = false,
  });
  final String label;
  final bool highlighted;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 8,
      vertical: compact ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: highlighted ? CustomerColors.selection : catalogPaper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: highlighted ? CustomerColors.primary : CustomerColors.text,
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class BookingSummaryTile extends StatelessWidget {
  const BookingSummaryTile({
    super.key,
    required this.booking,
    required this.name,
    required this.onTap,
  });
  final Map<String, dynamic> booking;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: const Color(0xFFF0FAF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFBFDCD8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('customer-booking-${booking['jobId']}'),
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FDFC), Color(0xFFE8F7F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final stacked =
                    bounds.maxWidth < 290 ||
                    MediaQuery.textScalerOf(context).scale(12) > 16;
                final status = _BookingStatusBadge(status: booking['status']);
                final paymentInk =
                    {
                      'PENDING',
                      'NOT_STARTED',
                    }.contains(booking['paymentStatus'])
                    ? const Color(0xFF906320)
                    : booking['paymentStatus'] == 'FAILED'
                    ? const Color(0xFFB6404A)
                    : const Color(0xFF327D70);
                final payment = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (booking['paymentMethod'] == 'WALLET')
                      SvgPicture.asset(
                        'assets/icons/navigation/wallet_selected.svg',
                        width: 15,
                        height: 15,
                        colorFilter: ColorFilter.mode(
                          paymentInk,
                          BlendMode.srcIn,
                        ),
                      )
                    else
                      Icon(
                        booking['paymentMethod'] == 'CARD'
                            ? Icons.credit_card_rounded
                            : Icons.payments_outlined,
                        size: 15,
                        color: paymentInk,
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bookingPaymentLabel(booking['paymentStatus']),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: paymentInk,
                        ),
                      ),
                    ),
                  ],
                );
                final amount =
                    booking['expectedAmount'] is num &&
                        booking['currencyCode'] is String
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          walletMoney(booking['expectedAmount']).replaceFirst(
                            'Rs.',
                            booking['currencyCode'] == 'LKR'
                                ? 'Rs.'
                                : '${booking['currencyCode']}',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CustomerColors.primary,
                          ),
                        ),
                      )
                    : null;
                final schedule =
                    (booking['startDatetime'] ?? booking['requestedPickupTime'])
                        as String?;
                final date = DateTime.tryParse(schedule ?? '');
                const months = [
                  'JAN',
                  'FEB',
                  'MAR',
                  'APR',
                  'MAY',
                  'JUN',
                  'JUL',
                  'AUG',
                  'SEP',
                  'OCT',
                  'NOV',
                  'DEC',
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCEF0E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: date == null
                              ? const Icon(
                                  Icons.event_note_outlined,
                                  color: CustomerColors.action,
                                  size: 24,
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      months[date.month - 1],
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: CustomerColors.action,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                    Text(
                                      '${date.day}',
                                      style: const TextStyle(
                                        fontSize: 21,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                        color: CustomerColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        fontWeight: FontWeight.w700,
                                        color: CustomerColors.text,
                                      ),
                                    ),
                                  ),
                                  if (!stacked) ...[
                                    const SizedBox(width: 8),
                                    status,
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Booking #${booking['jobId']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CustomerColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bookingDisplayTime(context, schedule),
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: CustomerColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (stacked) ...[
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: status),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 9),
                      child: Divider(height: 1, color: Color(0xFFEDF3F3)),
                    ),
                    if (stacked) ...[
                      payment,
                      if (amount != null) ...[
                        const SizedBox(height: 8),
                        amount,
                      ],
                    ] else
                      Row(
                        children: [
                          Expanded(child: payment),
                          if (amount != null) ...[
                            const SizedBox(width: 10),
                            amount,
                          ],
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: CustomerColors.action,
                            size: 18,
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});
  final Object? status;
  @override
  Widget build(BuildContext context) {
    final closed = {'CANCELLED', 'REJECTED', 'EXPIRED'}.contains(status);
    final completed = status == 'COMPLETED';
    final ink = closed
        ? const Color(0xFFB22E3C)
        : completed
        ? const Color(0xFF147D68)
        : CustomerColors.action;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: closed
            ? const Color(0xFFFFE4E7)
            : completed
            ? const Color(0xFFD9F3E4)
            : const Color(0xFFCFF1EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        bookingStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}
