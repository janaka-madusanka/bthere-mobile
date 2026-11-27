import '../../../app/widgets/customer_content_surface.dart';
import '../../../app/widgets/customer_home_skeleton.dart';
import 'customer_booking_details_screen.dart';
import '../../discovery/presentation/customer_bottom_navigation.dart';
import '../../../app/widgets/customer_top_bar.dart';
export '../application/customer_booking_history.dart'
    show customerBookingHistoryProvider;
import '../application/customer_booking_history.dart';
import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
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
        backgroundColor: catalogTeal,
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
          surfaceColor: CustomerColors.pageBackground,
        ),
        body: Column(
          children: [
            if (asOpportunities)
              const CustomerTopBar(extendBehindContent: true),
            Expanded(
              child: CustomerContentSurface(
                color: CustomerColors.pageBackground,
                child: history == null
                    ? const CustomerBookingsSkeleton()
                    : history.when(
                        skipLoadingOnReload: true,
                        skipLoadingOnRefresh: true,
                        skipError: history.hasValue,
                        loading: () => const CustomerBookingsSkeleton(),
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
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in ['All', 'Active', 'Completed', 'Cancelled'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    avatar: filter == 'All'
                        ? null
                        : Icon(
                            switch (filter) {
                              'Active' => Icons.play_circle_outline_rounded,
                              'Completed' => Icons.check_rounded,
                              _ => Icons.cancel_outlined,
                            },
                            size: 16,
                            color: _filter == filter
                                ? Colors.white
                                : const Color(0xFF101D42),
                          ),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                    selectedColor: CustomerColors.action,
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    labelStyle: CustomerTypography.compactStrong.copyWith(
                      color: _filter == filter
                          ? Colors.white
                          : const Color(0xFF101D42),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  style: CustomerTypography.card.copyWith(
                    color: CustomerColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your service bookings will appear here.',
                  textAlign: TextAlign.center,
                  style: CustomerTypography.compact.copyWith(
                    color: CustomerColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          final booking = rows[index - 1];
          return BookingSummaryTile(
            booking: booking,
            name:
                widget.serviceNames[booking['serviceTypeId']] ??
                'Service booking',
            onTap: () => widget.onOpen(booking),
          );
        },
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
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const CustomerRecentBookingsSkeleton(),
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
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: CustomerColors.selection,
                    child: Icon(Icons.history_rounded, color: catalogTeal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent bookings yet.',
                          style: CustomerTypography.card.copyWith(
                            color: catalogInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your services will appear here after booking.',
                          style: CustomerTypography.compact.copyWith(
                            color: catalogMuted,
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
                        style: CustomerTypography.card.copyWith(
                          color: catalogInk,
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
                        style: CustomerTypography.compact.copyWith(
                          color: catalogMuted,
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
                              bookingStatus: booking['status'],
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
      style: CustomerTypography.compactStrong.copyWith(
        color: highlighted ? CustomerColors.primary : CustomerColors.text,
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
  Widget build(BuildContext context) {
    final schedule =
        (booking['startDatetime'] ?? booking['requestedPickupTime']) as String?;
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
    final amount =
        booking['expectedAmount'] is num && booking['currencyCode'] is String
        ? walletMoney(booking['expectedAmount']).replaceFirst(
            'Rs.',
            booking['currencyCode'] == 'LKR'
                ? 'Rs.'
                : '${booking['currencyCode']}',
          )
        : null;
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: CustomerTypography.card.copyWith(
            color: const Color(0xFF101D42),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Booking #${booking['jobId']}',
          style: CustomerTypography.compact.copyWith(
            color: CustomerColors.secondaryText,
          ),
        ),
      ],
    );
    final result = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _BookingStatusBadge(status: booking['status']),
        if (amount != null) ...[
          const SizedBox(height: 8),
          Text(
            amount,
            textAlign: TextAlign.right,
            style: CustomerTypography.card.copyWith(
              color: CustomerColors.action,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label:
            '${bookingDisplayTime(context, schedule)}, ${bookingPaymentLabel(booking['paymentStatus'], bookingStatus: booking['status'])}',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('customer-booking-${booking['jobId']}'),
            onTap: onTap,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFF3FAFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final stacked =
                      bounds.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        constraints: const BoxConstraints(minHeight: 54),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF3F1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: date == null
                            ? const Icon(
                                Icons.event_note_outlined,
                                color: CustomerColors.action,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    months[date.month - 1],
                                    textAlign: TextAlign.center,
                                    style: CustomerTypography.micro.copyWith(
                                      color: CustomerColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '${date.day}',
                                    textAlign: TextAlign.center,
                                    style: CustomerTypography.screen.copyWith(
                                      color: CustomerColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  summary,
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: result,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: summary),
                                  const SizedBox(width: 8),
                                  Expanded(child: result),
                                ],
                              ),
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
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});
  final Object? status;
  @override
  Widget build(BuildContext context) {
    final closed = {'CANCELLED', 'REJECTED', 'EXPIRED'}.contains(status);
    final completed = status == 'COMPLETED';
    final ink = closed
        ? const Color(0xFFC43443)
        : completed
        ? const Color(0xFF23723A)
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (closed || completed) ...[
            Icon(
              completed ? Icons.check_rounded : Icons.cancel_outlined,
              size: 15,
              color: ink,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              bookingStatusLabel(status),
              style: CustomerTypography.compactStrong.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerBookingsSkeleton extends StatelessWidget {
  const CustomerBookingsSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0F1),
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Semantics(
      label: 'Loading bookings',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          key: const ValueKey('bookings-loading-skeleton'),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: block(26, width: 145),
                  ),
                ),
                block(32, width: 38),
              ],
            ),
            const SizedBox(height: 10),
            block(14),
            const SizedBox(height: 22),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                      child: block(38),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CustomerColors.border),
                ),
                child: Row(
                  children: [
                    block(56, width: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          block(16),
                          const SizedBox(height: 10),
                          block(12, width: 76),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    block(26, width: 72),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
